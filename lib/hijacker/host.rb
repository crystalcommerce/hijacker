class Hijacker::Host < Hijacker::BaseModel
  validates_format_of :hostname, :with => /\A(#{URI::REGEXP::PATTERN::HOST}|#{URI::REGEXP::PATTERN::IPV6ADDR})\z/
end
