namespace :hijacker do

  # Create a lookup hash for database host ipaddresses, translating to the more
  # human readable name (e.g., 'ds1204')
  require 'csv'
  require_relative '../lib/hijacker/redis_keys'
  require 'redis'
  require_relative '../config/initializers/redis'
  
  desc "Update Redis db ip address to hostname translation table using ./example/host_translations.csv"
  task :setup_translation_table do |t, args|
    extend Hijacker::RedisKeys

    redis_config = (args and args.extras and args.extras.length > 0 and !args.extras[0].nil? and File.exists?(args.extras[0]) and args.extras[0])
    if redis_config
      $hijacker_redis = Redis.new(JSON.load(redis_config))
    else
      $hijacker_redis = Redis.new
    end
    
    default_filepath = "#{File.expand_path(File.dirname(__FILE__))}/../example/host_translations.csv"
    custom_filepath = (args and args.extras and args.extras.length > 1 and File.exists?(args.extras[1]) and args.extras[1])
    filepath = (custom_filepath or default_filepath)

    if File.exists?(filepath)
      # Make sure that file exists and can be parsed before deleting
      # translation hash from Redis
      data = CSV.parse(IO.read(filepath), { headers: true, converters: :numeric, header_converters: :symbol })

      $hijacker_redis.del(redis_keys(:host_translations))
      data.each do |row|
        next unless row[:ipaddr] and row[:ipaddr].length > 0
        $hijacker_redis.hmset("#{redis_keys(:host_translations)}:#{row[:ipaddr]}", :hostname, row[:hostname], :hostid, row[:hostid])
        $hijacker_redis.sadd("#{redis_keys(:host_translations)}", row[:ipaddr])
      end
    end
  end
end

