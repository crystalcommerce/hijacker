# Use this in core app to use a different Redis server for Hijacker
module Hijacker
  module Redis
    def self.connect(redis_connection)
      $hijacker_redis = redis_connection
    end
  end
end
