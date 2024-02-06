#Dummy exceptions if driver not loaded
if !defined?(Mysql2)
  module Mysql2
    class Error < StandardError
      attr_accessor :errno
    end
  end
end

if !defined?(Mysql)
  module Mysql
    class Error < StandardError
      attr_accessor :errno
    end
  end
end

class Hijacker::Database < Hijacker::BaseModel
  module MissingDatabaseError
    MYSQL_UNKNOWN_DB_ERRNO = 1049

    def self.===(e)
      return true if e.is_a?(Hijacker::InvalidDatabase)
      (e.is_a?(Mysql::Error) || e.is_a?(Mysql2::Error)) &&
        e.errno == MYSQL_UNKNOWN_DB_ERRNO
    end
  end

  has_many :aliases, :class_name => "Hijacker::Alias"
  belongs_to :master, :foreign_key => 'master_id', :class_name => 'Hijacker::Database'
  has_many :sisters, :foreign_key => 'master_id', :class_name => 'Hijacker::Database'
  belongs_to :host, :class_name => "Hijacker::Host"

  validates_uniqueness_of :database

  validates_presence_of :host_id

  alias_attribute :name, :database

  def self.cached_unresponsive_host_ids
    Hijacker.all_unresponsive_dbhost_ids
  end

  scope :with_responsive_hosts, ->(*_) {
    host_ids = cached_unresponsive_host_ids
    if(host_ids and host_ids.length > 0)
      where(["host_id not in (?)", host_ids])
    else
      scoped
    end
  }

  def sister?
    master_id.present?
  end

  def self.find_by_name(name)
    find_by_database(name)
  end

  def self.current
    find(:first, :conditions => {:database => Hijacker.current_client})
  end

  # returns a string or nil
  def self.find_master_for(client, try_again=true)
    client.to_s
    #@masters ||= {}
    #begin
    #  @masters[client] ||= self.connection.select_values(
    #    "SELECT master.database "\
    #    "FROM `databases` AS master, `databases` AS sister "\
    #    "WHERE sister.database = #{ActiveRecord::Base.connection.quote(client)} "\
    #    "AND sister.master_id = master.id"
    #  ).first
    #rescue ActiveRecord::ConnectionNotEstablished
    #  ActiveRecord::Base.establish_connection('root')
    #  if try_again
    #    self.find_master_for(client, false) # one attempt only!
    #  else
    #    raise "Failed to establish connection"
    #  end
    #end
  end

  # always returns a master, sister can be nil
  def self.find_master_and_sister_for(client)
    master = self.find_master_for(client)
    sister = master.nil? ? nil : client
    master ||= client

    return master, sister
  end

  def self.shared_sites
    self.find_shared_sites_for(Hijacker.current_client)
  end

  def self.connect_to_each_shared_site(&block)
    connect_each(find_shared_sites_for(Hijacker.current_client), &block)
  end

  def self.connect_to_each_sister_site(&block)
    sites = find_shared_sites_for(Hijacker.current_client)
    sites.delete(Hijacker.current_client)
    connect_each(sites, &block)
  end

  def self.find_shared_sites_for(client)
    @shared_sites ||= {}
    return @shared_sites[client] if @shared_sites[client].present?

    current = self.find(:first, :conditions => {:database => client})
    master_id = current.master_id || current.id

    @shared_sites[client] = self.connection.select_values(
      "SELECT `database`
      FROM `databases`
      WHERE master_id = '#{master_id}' OR id = '#{master_id}'
      ORDER BY id"
    )
  end

  # Now by default, unresponsive hosts will be filtered out
  #
  # Also, if a host triggers an unresponsive response before the threshold is
  # met, the bad database threshold count is incremented and the loop continues
  # to the next database
  #
  # In some cases, it may still be desireable to allow exceptions to be raised.
  # That behavior can be accomplished as follows:
  #
  # Hijacker::Database.connect_each(Hijacker::Database.all, {validate_unresponsive_hosts: false}) do |db| ... end
  #
  def self.connect_each(sites = with_responsive_hosts.map(&:database), options={})
    options = {validate_connections: true, validate_unresponsive_hosts: true}.merge(options)
    options = {guard_all_yielded_exceptions: false}.merge(options)

    original_database = Hijacker.current_client
    begin
      sites.each do |db|
        begin
          Hijacker.connect_to_master(db)

        rescue Hijacker::UnresponsiveHostError => error
          Hijacker.logger.warn "[Hijacker::Database] unable to connect to #{db}; #{error.message}"
          raise unless(options[:validate_connections] and options[:validate_unresponsive_hosts])
          next

        rescue => error # MissingDatabaseError
          Hijacker.logger.warn "[Hijacker::Database] unable to connect to #{db}; #{error.message}"
          raise unless options[:validate_connections]
          next
        end

        begin
          yield db
        rescue => error
          Hijacker.logger.warn "[Hijacker::Database] unable to yield code block for #{db}; #{error.message}"
          raise error unless options[:guard_all_yielded_exceptions]
        end
      end
    ensure
      begin
        Hijacker.logger.debug "reconnecting to #{(original_database)}"
        Hijacker.connect_to_master(original_database)
      rescue MissingDatabaseError
      end
    end
  end

  def self.count_each(options = {}, &blk)
    acc = {}

    if options.fetch(:progress, true)
      require 'progress'
      Progress.start("Counting...", count) do
        connect_each do |db|
          count = blk.call
          acc[db] = count if count > 0
          Progress.step
        end
      end
    else
      connect_each do |db|
        count = blk.call
        acc[db] = count if count > 0
      end
    end

    if options.fetch(:print, true)
      width = acc.keys.map(&:length).max
      acc.sort_by(&:last).each do |db, count|
        puts("%#{width}s: %s" % [db, count])
      end
    end

    acc
  end

  def self.disabled_databases
    Hijacker::Database.connection.select_values("SELECT `database_name` FROM `disabled_databases`")
  end

  def disable!
    Hijacker::Database.connection.
      execute("REPLACE INTO `disabled_databases` (`database_name`) VALUES ('#{database}')")
  end

  def enable!
    Hijacker::Database.connection.
      execute("DELETE FROM `disabled_databases` WHERE `database_name` = '#{database}'")
  end

private
  def self.catch_missing_database(&block)
    block.call
  end
end
