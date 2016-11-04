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

  attr_accessor :yaml_host, :yaml_master, :yaml_sisters

  def host
    yaml_host.present? ? yaml_host : super
  end
  
  def master
    yaml_master.present? ? yaml_master : super
  end
  
  def sisters
    yaml_sisters.present? ? yaml_sisters : super
  end

  def sister?
    master_id.present?
  end

  def self.find_by_name(name)
    if has_hijacker_yml?
      hijacker_yaml[name].present? ? 
        new_from_yaml(hijacker_yaml[name]) :
        nil
    else
      find_by_database(name)      
    end
  end
  
  def self.new_from_yaml(data)
    sisters_data  = data.delete(:sisters)
    master_data   = data.delete(:master)
    host_data     = data.delete(:host)
    data          = data.delete(:database)
    id            = data.delete(:id)

    db = new(data)
    db.id   = id

    if host_data.present?
      host_id = host_data.delete(:id)
      db.yaml_host = Hijacker::Host.new(host_data)
      db.host_id = db.host.id = host_id
    end

    if master_data.present?
      master_id = master_data.delete(:id)
      db.yaml_master = Hijacker::Database.new_from_yaml(master_data)
      db.master_id = db.master.id = master_id
    end
    
    if sisters_data.present?
      db.yaml_sisters = sisters_data.map do |sister_data|
        sister_id = sister_data.delete(:id)
        sister = Hijacker::Database.new_from_yaml(sister_data)
        sister.id = sister_id
        sister
      end
    end

    db
  end
  
  def self.hijacker_path
    Rails.root.join('config', 'hijacker.yml')
  end
  
  def self.hijacker_yaml
    YAML::load_file(hijacker_path)
  end
  
  def self.has_hijacker_yml?
    File.exist?(hijacker_path)
  end

  def self.current
    if has_hijacker_yml?
      hijacker_yaml[Hijacker.current_client].present? ? 
        Hijacker::Database.new_from_yaml(hijacker_yaml[Hijacker.current_client]) :
        nil
    else
      find(:first, :conditions => {:database => Hijacker.current_client})
    end
  end

  # returns a string or nil
  def self.find_master_for(client, try_again=true)
    @masters ||= {}
    
    
    if has_hijacker_yml?
      @masters[client] ||= hijacker_yaml[client][:master][:database][:database]
    else
      begin
        @masters[client] ||= self.connection.select_values(
          "SELECT master.database "\
          "FROM `databases` AS master, `databases` AS sister "\
          "WHERE sister.database = #{ActiveRecord::Base.connection.quote(client)} "\
          "AND sister.master_id = master.id"
        ).first
      rescue ActiveRecord::ConnectionNotEstablished
        ActiveRecord::Base.establish_connection('root')
        if try_again
          self.find_master_for(client, false) # one attempt only!
        else
          raise "Failed to establish connection"
        end
      end      
    end
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

  def self.connect_each(sites = all.map(&:database))
    original_database = Hijacker.current_client
    begin
      sites.each do |db|
        begin
          Hijacker.connect_to_master(db)
        rescue MissingDatabaseError
          next
        end
        yield db
      end
    ensure
      begin
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
