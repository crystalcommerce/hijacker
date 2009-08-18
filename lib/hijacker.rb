require 'hijacker/active_record_ext'

module Hijacker
  class UnparseableURL < StandardError;end
  class InvalidDatabase < StandardError;end
  
  class << self
    attr_accessor :config, :master, :sister
  end

  # Manually establishes a new connection to the database.
  # 
  # Background: every time rails gets information
  # from the database, it uses the last established connection. So,
  # although we've already established a connection to a "dummy" db
  # ("crystal", in this case), if we establish a new connection, all
  # subsequent database calls will use these settings instead (well,
  # until it's called again when it gets another request).
  # 
  # Note that you can manually call this from script/console (or wherever)
  # to connect to the database you want, ex Hijacker.connect("database")
  def self.connect(master, sister = nil)
    hijacked_config = self.root_connection.config.dup
    hijacked_config[:database] = master
    ActiveRecord::Base.establish_connection(hijacked_config)
    
    # just calling establish_connection doesn't actually check to see if
    # we've established a VALID connection. a call to connection will check
    # this, and throw an error if the connection's invalid. It is important 
    # to catch the error and reconnect to a known valid database or rails
    # will get stuck. This is because once we establish a connection to an
    # invalid database, the next request will do a courteousy touch to the
    # invalid database before reaching establish_connection and throw an error,
    # preventing us from retrying to establish a valid connection and effectively
    # locking us out of the app.
    begin
      ActiveRecord::Base.connection
    rescue => e
      raise Hijacker::InvalidDatabase, master
    end
    
    self.connect_sister_site_models(sister || master)
    
    self.master = master
    self.sister = sister
    
    # This is a hack to get query caching back on. For some reason when we
    # reconnect the database during the request, it stops doing query caching.
    # We couldn't find how it's used by rails originally, but if you turn on
    # query caching then start a cache block to initialize the @query_cache
    # instance variable in the connection, AR will from then on build on that
    # empty @query_cache hash. You have to do both 'cuz without the latter there
    # will be no @query_cache available. Maybe someday we'll submit a ticket to Rails.
    if ActionController::Base.perform_caching
      ActiveRecord::Base.connection.instance_variable_set("@query_cache_enabled", true)
      ActiveRecord::Base.connection.cache do;end
    end
    
    self.config[:after_hijack].call if self.config[:after_hijack]
  rescue => e
    self.establish_root_connection
    raise e
  end
  
  # very small change this will raise, but if it does, we still want to treat it the
  # same as connect so we don't lock up the app
  def self.connect_sister_site_models(db)
    return if db.nil?
    
    self.config[:sister_site_models].each do |model_name|
      ar_model = model_name.constantize
      model_name.constantize.establish_connection(self.root_connection.config.merge(:database => db))
      begin
        ar_model.connection
      rescue
        ar_model.establish_connection(self.root_connection.config)
        raise Hijacker::InvalidDatabase, db
      end
    end
  end

  # connects the sister_site_models to +db+ while calling the block
  # if +db+ and self.master differ
  def self.temporary_sister_connect(db, &block)
    processing_sister_site = (db != self.master && db != self.sister)
    self.connect_sister_site_models(db) if processing_sister_site
    block.call
    self.connect_sister_site_models(self.master) if processing_sister_site
  end
  
  # maintains and returns a live (i.e. guarunteed to not be dead) connection
  # to the "dummy" database. 
  # 
  # The advantage of using this over just calling
  # ActiveRecord::Base.establish_connection (without arguments) to reconnect
  # to the dummy database is that reusing the same connection greatly reduces
  # context switching overhead etc involved with establishing a connection to
  # the database. It may seem trivial, but it actually seems to speed things
  # up by ~ 1/3 for already fast requests (probably less noticeable on slower
  # pages).
  def self.root_connection
    if !$hijacker_root_connection
      ActiveRecord::Base.establish_connection # establish with defaults
      $hijacker_root_connection = ActiveRecord::Base.connection
    end
    
    if $hijacker_root_connection.raw_connection.stat == "MySQL server has gone away"
      $hijacker_root_connection.reconnect!
    end
    
    return $hijacker_root_connection
  end
  
  # this should establish a connection to a database containing the bare minimum
  # for loading the app, usually a sessions table if using sql-based sessions.
  def self.establish_root_connection
    ActiveRecord::Base.establish_connection(self.root_connection.config)
  end
  
  def self.processing_sister_site?
    !sister.nil?
  end
  
  def self.current_client
    sister || master
  end
end
