class Hijacker::Host < Hijacker::BaseModel

  validates_format_of :hostname, :with => /\A(#{URI::REGEXP::PATTERN::HOST}|#{URI::REGEXP::PATTERN::IPV6ADDR})\z/
  belongs_to :slave, class_name: "Hijacker::Host"

end
