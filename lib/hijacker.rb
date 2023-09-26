require_relative './hijacker/active_record_ext'
require_relative './hijacker/request_parser'
require_relative './hijacker/unresponsive_host_error'
require_relative './hijacker/redis_keys'
require_relative './hijacker/logging'
require_relative './hijacker/mysql_errors'
require 'active_record'
require 'action_controller'
require 'set'

require_relative '../config/initializers/settings'

module Hijacker
  extend RedisKeys
  extend Logging
  extend MysqlErrors

  DEFAULT_UNRESPONSIVE_DBHOST_COUNT_THRESHOLD = (APP_CONFIG[:unresponsive_dbhost_count_threshold] or 10).to_i

  class << self
    attr_accessor :config, :master, :sister, :user_collection_id
    attr_writer :valid_routes
  end

  def self.valid_routes
    @valid_routes ||= {}
  end

  def self.connect_to_master(db_name)
    connect(*Hijacker::Database.find_master_and_sister_for(db_name))
  end

  # Manually establishes a new connection to the database.
  #
  # Background: every time rails gets information
  # from the database, it uses the last established connection. So,
  # although we've already established a connection to a root db
  # ("crystal", in this case), if we establish a new connection, all
  # subsequent database calls will use these settings instead (well,
  # until it's called again when it gets another request).
  #
  # Note that you can manually call this from script/console (or wherever)
  # to connect to the database you want, ex Hijacker.connect("database")
  def self.connect(target_name, sister_name = nil, options = {})
    original_database = Hijacker::Database.current
    database = nil
    exception = nil

    begin
      raise InvalidDatabase.new(nil, 'master cannot be nil') if target_name.nil?

      target_name = target_name.downcase
      sister_name = sister_name.downcase unless sister_name.nil?

      if already_connected?(target_name, sister_name, options[:slave])
        run_after_hijack_callback
        return "Already connected to #{target_name}"
      end

      database = determine_database(target_name, sister_name)

      logger.debug "establishing connection to #{database.attributes}"
      establish_connection_to_database(database, options[:slave])

      logger.debug "checking connection to #{database.attributes} (actually make the connection)"
      check_connection

      if database.sister?
        self.master = database.master.name
        self.sister = database.name
      else
        self.master = database.name
        self.sister = nil
      end

      # don't cache sister site
      cache_database_route(target_name, database) unless sister_name

      # Do this even on a site without a master so we reconnect these models
      connect_sister_site_models(database.master || database)

      reenable_query_caching

      run_after_hijack_callback

      logger.debug "#{database.host} was responsive; resetting counter"
      reset_unresponsive_dbhost(host_data(database.host))

    rescue Mysql2::Error => e
      exception = mysql_error(e).new(e)
    rescue => e
      exception = e
    ensure
      if exception
        if original_database.present?
          establish_connection_to_database(original_database)
        else
          self.establish_root_connection
        end

        raise exception 
      end
    end
  end

  def self.host_data(host)
    HashWithIndifferentAccess.new({ip_address: host.hostname, hostname: host.common_hostname})
  end

  def self.dbhost(conn_config)
    (conn_config and conn_config.has_key?(:host) and conn_config[:host])
  end

  def self.slave_connect(target_name, sister_name = nil, options = {})
    connect(target_name, sister_name = nil, options.merge(slave: true))
  end

  # very small chance this will raise, but if it does, we will still handle it the
  # same as +Hijacker.connect+ so we don't lock up the app.
  #
  # Also note that sister site models share a connection via minor management of
  # AR's connection_pool stuff, and will use ActiveRecord::Base.connection_pool if
  # we're not in a sister-site situation
  def self.connect_sister_site_models(master_database)
    master_db_connection_pool = if processing_sister_site?
                                  nil
                                else
                                  ActiveRecord::Base.connection_pool
                                end
    master_config = connection_config(master_database)

    config[:sister_site_models].each do |model_name|
      klass = model_name.constantize

      klass.establish_connection(master_config)

      if !master_db_connection_pool
        begin
          klass.connection
        rescue
          klass.establish_connection(root_config)
          raise Hijacker::InvalidDatabase.new(database.name)
        end
        master_db_connection_pool = klass.connection_pool
      else
        ActiveRecord::Base.connection_handler.connection_pools[model_name] = master_db_connection_pool
      end
    end
  end

  # connects the sister_site_models to +db+ while calling the block
  # if +db+ and self.master differ
  def self.temporary_sister_connect(db, &block)
    processing_sister_site = (db != master && db != sister)
    self.sister = db if processing_sister_site
    self.connect_sister_site_models(db) if processing_sister_site
    result = block.call
    self.connect_sister_site_models(self.master) if processing_sister_site
    self.sister = nil if processing_sister_site

    result
  end

  # The advantage of using this over just calling
  # ActiveRecord::Base.establish_connection (without arguments) to reconnect
  # to the root database is that reusing the same connection greatly reduces
  # context switching overhead etc involved with establishing a connection to
  # the database. It may seem trivial, but it actually seems to speed things
  # up by ~ 1/3 for already fast requests (probably less noticeable on slower
  # pages).
  #
  # Note: does not hijack, just returns the root connection (i.e. AR::Base will
  # maintain its connection)
  def self.root_connection
    unless $hijacker_root_connection
      current_config = ActiveRecord::Base.connection.config
      ActiveRecord::Base.establish_connection('root') # establish with defaults
      $hijacker_root_connection = ActiveRecord::Base.connection
      ActiveRecord::Base.establish_connection(current_config) # reconnect, we don't intend to hijack
    end

    $hijacker_root_connection
  end

  def self.root_config
    database_configurations.fetch('root').with_indifferent_access
  end

  def self.database_configurations
    ActiveRecord::Base.configurations
  end

  # this should establish a connection to a database containing the bare minimum
  # for loading the app, usually a sessions table if using sql-based sessions.
  def self.establish_root_connection
    ActiveRecord::Base.establish_connection('root')
  end

  def self.processing_sister_site?
    !sister.nil?
  end

  def self.master
    @master || database_configurations.fetch(ENV['RAILS_ENV'] || Rails.env)['database']
  end

  def self.current_client
    sister || master
  end

  def self.current_user_collection_id
    target_name = master
    database = determine_database(target_name, nil)
    @user_collection_id || database.user_collection_id 
  end

  def self.do_hijacking?
    (Hijacker.config[:hosted_environments] || %w[staging production]).
      include?(ENV['RAILS_ENV'] || Rails.env)
  end

  # just calling establish_connection doesn't actually check to see if
  # we've established a VALID connection. a call to connection will check
  # this, and throw an error if the connection's invalid. It is important
  # to catch the error and reconnect to a known valid database or rails
  # will get stuck. This is because once we establish a connection to an
  # invalid database, the next request will do a courteousy touch to the
  # invalid database before reaching establish_connection and throw an error,
  # preventing us from retrying to establish a valid connection and effectively
  # locking us out of the app.
  def self.check_connection
    ::ActiveRecord::Base.connection
  end

private

  def self.already_connected?(new_master, new_sister, slave_connection)
    return false if slave_connection # We always reconnect to slaves just in case
    current_client == new_master && sister == new_sister
  end

  def self.determine_database(target_name, sister_name)
    if sister_name
      database = Hijacker::Database.find_by_name(sister_name)
      raise(Hijacker::InvalidDatabase.new(sister_name)) if database.nil?
      database
    elsif valid_routes[target_name]
      valid_routes[target_name] # cached valid database
    else
      database = Hijacker::Alias.find_by_name(target_name).try(:database) || Hijacker::Database.find_by_name(target_name)
      raise(Hijacker::InvalidDatabase.new(target_name)) if database.nil?
      database
    end
  end

  def self.cache_database_route(requested_db_name, actual_database)
    valid_routes[requested_db_name] ||= actual_database
  end

  def self.establish_connection_to_database(database, slave_connection = false)
    ::ActiveRecord::Base.establish_connection(connection_config(database, slave_connection))
  end

  # This is a hack to get query caching back on. For some reason when we
  # reconnect the database during the request, it stops doing query caching.
  # We couldn't find how it's used by rails originally, but if you turn on
  # query caching then start a cache block to initialize the @query_cache
  # instance variable in the connection, AR will from then on build on that
  # empty @query_cache hash. You have to do both 'cuz without the latter there
  # will be no @query_cache available. Maybe someday we'll submit a ticket to Rails.
  def self.reenable_query_caching
    if ::ActionController::Base.perform_caching
      ::ActiveRecord::Base.connection.instance_variable_set("@query_cache_enabled", true)
      ::ActiveRecord::Base.connection.cache do;end
    end
  end

  # TODO: fold slave_connection into options hash; not sure what kind of impact
  # it would have to refactor that at this time since it was pre-existing.
  def self.connection_config(database, slave_connection = false, options={check_responsiveness: true})
    host = slave_connection ? database.host.slave : database.host
    host ||= database.host
    hostname = host.proxy_hostname || host.hostname
    port = host.proxy_port || host.port || root_config['port']
    conn_config = root_config.merge('database' => database.name, 'host' => hostname, 'port' => port)

    if options[:check_responsiveness] and !dbhost_available?(dbhost(conn_config), {host_id: host.id})
      error = UnresponsiveHostError.new(conn_config)
      logger.warn "[Hijacker] error discovered; #{error.message}"
      raise error
    end

    conn_config
  end

  def self.run_after_hijack_callback
    config[:after_hijack].call if config[:after_hijack]
  end
end

require_relative './hijacker/base_model'
require_relative './hijacker/database'
require_relative './hijacker/alias'
require_relative './hijacker/host'
require_relative './hijacker/middleware'
require_relative './hijacker/controller_methods'

require 'redis'
require_relative '../config/initializers/redis'

