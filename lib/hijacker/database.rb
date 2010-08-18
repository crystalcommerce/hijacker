class Hijacker::Database < ActiveRecord::Base
  establish_connection(Hijacker.root_config)

  validates_uniqueness_of :database
  
  def self.current
    find(:first, :conditions => {:database => Hijacker.current_client})
  end
  
  # returns a string or nil
  def self.find_master_for(client)
    client = ActiveRecord::Base.connection.quote(client)
    self.connection.select_values(
      "SELECT master.database 
      FROM `databases` AS master, `databases` AS sister
      WHERE sister.database = #{client}
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
  
  def self.find_shared_sites_for(client)
    current = self.find(:first, :conditions => {:database => client})
    master_id = current.master_id || current.id
    
    self.connection.select_values(
      "SELECT database
      FROM `databases`
      WHERE master_id = '#{master_id}' OR id = '#{master_id}'"
    )
  end

  def self.connect_each
    all.each do |client|
      Hijacker.connect(client.database)
      yield client.database
    end
  end
end
