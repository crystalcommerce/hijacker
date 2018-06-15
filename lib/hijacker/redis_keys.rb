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
    DEFAULT_UNRESPONSIVE_DBHOST_COUNT_THRESHOLD = "hijacker:count_threshold"

    # Hash of database hosts that have been unresponsive for requests and the
    # count of such requests
    REDIS_UNRESPONSIVE_DBHOST_KEY = "hijacker:unresponsive-dbhosts"

    REDIS_UNRESPONSIVE_DBHOST_IDS_KEY = "hijacker:unresponsive-dbhost-ids"

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
      unresponsive_dbhost_ids: redis_key(REDIS_UNRESPONSIVE_DBHOST_IDS_KEY),
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

    def set_unresponsive_dbhost_count_threshold(threshold_count)
      begin
        $hijacker_redis.set( redis_keys(:unresponsive_dbhost_count_threshold), threshold_count )
      rescue
        # do nothing if Redis is unavailable
      end
    end

    # Get the current count for the number of times requests were not able to
    # connect to a given database host
    def unresponsive_dbhost_count(db_host)
      begin
        count = $hijacker_redis.hget( redis_keys(:unresponsive_dbhosts), db_host) unless db_host.nil?
        (count or 0).to_i
      rescue
        0
      end
    end

    def all_unresponsive_dbhosts
      begin
        $hijacker_redis.hgetall( redis_keys(:unresponsive_dbhosts) )
      rescue
        []
      end
    end

    def wipe_all_unresponsive_dbhosts
      begin
        $hijacker_redis.del( redis_keys(:unresponsive_dbhosts) )
      rescue
        # do nothing if Redis is unavailable
      end
    end

    def add_unresponsive_dbhost_id(db_host_id)
      begin
        $hijacker_redis.sadd( redis_keys(:unresponsive_dbhost_ids), db_host_id) unless db_host_id.nil?
      rescue
        # do nothing if Redis is unavailable
      end
    end

    def unresponsive_dbhost_id_exists?(db_host_id)
      begin
        $hijacker_redis.sismember( redis_keys(:unresponsive_dbhost_ids), db_host_id) unless db_host_id.nil?
      rescue
        false
      end
    end

    def all_unresponsive_dbhost_ids
      begin
        $hijacker_redis.smembers( redis_keys(:unresponsive_dbhost_ids) ).map(&:to_i)
      rescue
        []
      end
    end

    def remove_unresponsive_dbhost_id(db_host_id)
      begin
        $hijacker_redis.srem( redis_keys(:unresponsive_dbhost_ids), db_host_id) unless db_host_id.nil?
      rescue
        # do nothing if Redis is unavailable
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
        # I don't understand why it's necessary to delete the entry first, but
        # the other simply is not working;  this definitely works
        $hijacker_redis.pipelined do
          $hijacker_redis.hdel(redis_keys(:unresponsive_dbhosts), db_host)
          $hijacker_redis.hset(redis_keys(:unresponsive_dbhosts), db_host, 0)
        end
      rescue
        # do nothing if Redis is unavailable
      end
    end

    def hosts_translation_table
      begin
        host_entries = host_class.select('hostname,common_hostname')
        host_entries.inject({}){|h, entry| h.merge!(entry.hostname => (entry.common_hostname or entry.hostname))}
      rescue
        {}
      end
    end

    def dbhost_available?(host, options={})
      available = (host and (unresponsive_dbhost_count(host) < unresponsive_dbhost_count_threshold))

      if !available and options.has_key?(:host_id)
        add_unresponsive_dbhost_id(options[:host_id])
      end

      available
    end

    def increment_unresponsive_dbhost(host)
      if host
        redis_increment_unresponsive_dbhost(host)
      end
    end

    # For apps that require hijacker and make use of it's own models, there's nothing to do
    # For apps that provide their own models to access the crystal database (e.g., Support)
    # this method will need to be over written in the class that extends RedisKeys
    #
    # e.g.,
    #
    # def self.host_class
    #   ::Crystal::Host
    # end
    #
    def host_class
      ::Hijacker::Host
    end

    def reset_unresponsive_dbhost(host_attrs)
      hostname = (host_attrs and host_attrs[:ip_address])
      host = (hostname and host_class.where(hostname: hostname).first)

      if hostname and host
        redis_reset_unresponsive_dbhost(hostname)
        remove_unresponsive_dbhost_id(host.id)
        true

      else
        false
      end
    end

    # Translate from ip address to host name.  Simply return the ip address if
    # there is no matching translation.
    def translate_host_ip(host_ip_address)
      hosts_translation_table.fetch(host_ip_address, host_ip_address)
    end

  end
end
