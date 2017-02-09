# Segregate redis keys and redis calls to its own module for easier maintenance
# and so that it can be shared between code that pulls in ActiveRecord and code
# that does not.
#
# Since Hijacker is such an important piece of core code, make sure there is
# plenty of exception handling so that if Redis goes down, Hijacker doesn't add
# to the chaos.  Basically, if Redis is available, use it; otherwise, make sure
# the world doesn't come to an end.
# 
module Hijacker
  module RedisKeys

    # Hash of database hosts that have been unresponsive for requests and the
    # count of such requests
    REDIS_UNRESPONSIVE_DBHOST_KEY = "hijacker:unresponsive-dbhosts"

    # Hash of database host ip addresses with respective human friendly names
    REDIS_HOST_TRANSLATIONS_KEY = "hijacker:host-translations"

    # Scalar for the count after which Hijacker should not attempt to connect
    # to a database host
    REDIS_UNRESPONSIVE_DBHOST_COUNT_THRESHOLD_KEY = "hijacker:unresponsive-dbhosts:threshold-count"

    def self.rails_env
      Rails.env
    rescue
      "development"
    end
    
    # Namespace the redis keys using the current Rails environment
    # e.g., 'test:some-key', 'development:some-key', etc.
    def self.redis_key(key)
      app_env = (ENV['RAILS_ENV'] || rails_env)
      "#{app_env}:#{key}"
    end
    
    def rails_env
      Hijacker::RedisKeys.rails_env
    end

    def redis_key(key)
      Hijacker::RedisKeys.redis_key(key)
    end

    # Use this method to get the desired redis key
    def redis_keys(key)
      Hijacker::RedisKeys::REDIS_KEYS[key]
    end
    
    REDIS_KEYS = {
      unresponsive_dbhosts: redis_key(REDIS_UNRESPONSIVE_DBHOST_KEY), 
      host_translations: redis_key(REDIS_HOST_TRANSLATIONS_KEY), 
      unresponsive_dbhost_count_threshold: redis_key(REDIS_UNRESPONSIVE_DBHOST_COUNT_THRESHOLD_KEY)
    }

    # Get the threshold value for the number of times after which Hijacker
    # should not connect to a given database host
    #
    # 1. check for value in redis ('<rails-env>:hijacker:unresponsive-dbhosts:threshold-count')
    # 2. use value in external configuration file
    # 3. use static default (10)
    def unresponsive_dbhost_count_threshold
      begin
        ($hijacker_redis.get( redis_keys(:unresponsive_dbhost_count_threshold) ) or DEFAULT_UNRESPONSIVE_DBHOST_COUNT_THRESHOLD).to_i
      rescue
        DEFAULT_UNRESPONSIVE_DBHOST_COUNT_THRESHOLD
      end
    end

    # Get the current count for the number of times requests were not able to
    # connect to a given database host
    def redis_unresponsive_dbhost_count(db_host)
      begin
        count = $hijacker_redis.hget( redis_keys(:unresponsive_dbhosts), db_host) unless db_host.nil?
        (count or 0).to_i
      rescue
        0
      end
    end
    
    # Increment for a given database host the number of times requests were not
    # able to connect to a given database host
    def redis_increment_unresponsive_dbhost(db_host)
      begin
        $hijacker_redis.hincrby(redis_keys(:unresponsive_dbhosts), db_host, 1) unless db_host.nil?
      rescue
        # do nothing if Redis is unavailable
      end
    end

    # Reset count for unresponsive db host
    def redis_reset_unresponsive_dbhost(db_host)
      begin
        $hijacker_redis.hset(redis_keys(:unresponsive_dbhosts), db_host, 0) unless db_host.nil?
      rescue
        # do nothing if Redis is unavailable
      end
    end

    def redis_translation_table
      begin
        $hijacker_redis.hgetall(redis_keys(:host_translations))
      rescue
        {}
      end
    end
  end
end
