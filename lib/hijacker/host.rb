class Hijacker::Host < Hijacker::BaseModel
  self.primary_key = :id
  attr_accessible :hostname, :common_hostname, :port, :slave_id, :instance_name

  validates_format_of :hostname, :with => /^(#{URI::REGEXP::PATTERN::HOST}|#{URI::REGEXP::PATTERN::IPV6ADDR})$/
  belongs_to :slave, :foreign_key => 'slave_id', class_name: "Hijacker::Host"

end
