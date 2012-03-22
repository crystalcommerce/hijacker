class Hijacker::Database < ActiveRecord::Base
  establish_connection(Hijacker.root_config)

  has_many :aliases, :class_name => "Hijacker::Alias"
  belongs_to :master, :foreign_key => 'master_id', :class_name => 'Hijacker::Database'
  has_many :sisters, :foreign_key => 'master_id', :class_name => 'Hijacker::Database'
  belongs_to :host, :class_name => "Hijacker::Host"

  validates_uniqueness_of :database

  validates_presence_of :host_id

  alias_attribute :name, :database

  def self.find_by_name(name)
    find_by_database(name)
  end

  def self.current
    find(:first, :conditions => {:database => Hijacker.current_client})
  end
  
  # returns a string or nil
  def self.find_master_for(client)
    @masters ||= {}
    @masters[client] ||= self.connection.select_values(
        "SELECT master.database 
        FROM `databases` AS master, `databases` AS sister
        WHERE sister.database = #{ActiveRecord::Base.connection.quote(client)}
        AND sister.master_id = master.id"
      ).first
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
        Hijacker.connect_to_master(db)
        yield db
      end
    ensure
      begin
        Hijacker.connect_to_master(original_database)
      rescue Hijacker::InvalidDatabase
      end
    end
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
end
