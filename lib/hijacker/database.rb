class Hijacker::Database < ActiveRecord::Base
  establish_connection(Hijacker.root_connection.config)

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
end