class Hijacker::Host < ActiveRecord::Base
  establish_connection(Hijacker.root_config)

  validates_format_of :hostname, :with => /^(#{URI::REGEXP::PATTERN::HOST}|#{URI::REGEXP::PATTERN::IPV6ADDR})$/
end
