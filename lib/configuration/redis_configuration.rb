require 'yaml'
module RedisConfiguration
  def self.host
    config_hash[:host]
  end

  def self.port
    config_hash[:port]
  end

  def self.config_hash
    conf = YAML::load_file(File.dirname(__FILE__) + "/../../config/redis.yml")

    conf.fetch('defaults')
  end
end
