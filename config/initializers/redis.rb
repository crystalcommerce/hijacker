require_relative '../../lib/configuration/redis_configuration'
require_relative '../../lib/hijacker/redis'

Hijacker::Redis.connect Redis.new(RedisConfiguration.config_hash)
