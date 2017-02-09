require 'rake'
require 'rdoc/task'
require 'rubygems/package_task'

desc 'Generate documentation for the hijacker plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Hijacker'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

spec = Gem::Specification.load("dbhijacker.gemspec")
Gem::PackageTask.new(spec) {}

desc "Push latest gem version"
task :release => :gem do
  sh "gem push pkg/#{spec.name}-#{spec.version}.gem"
end

# Create a lookup hash for database host ipaddresses, translating to the more
# human readable name (e.g., 'ds1204')
require 'csv'
require_relative './lib/hijacker/redis_keys'
require 'redis'
require_relative './config/initializers/redis'

namespace :hijacker do
  desc "Update Redis db ip address to hostname translation table using ./example/host_translations.csv"
  task :setup_translation_table do |t, args|
    extend Hijacker::RedisKeys

    default_filepath = "./example/host_translations.csv"
    custom_filepath = (args and args.extras and args.extras.length > 0 and File.exists?(args.extras[0]) and args.extras[0])
    filepath = (custom_filepath or default_filepath)

    if File.exists?(filepath)
      # Make sure that file exists and can be parsed before deleting
      # translation hash from Redis
      data = CSV.parse(IO.read(filepath), { headers: true, converters: :numeric, header_converters: :symbol })

      $hijacker_redis.del(redis_keys(:host_translations))
      data.each do |row|
        next unless row[:ipaddr] and row[:ipaddr].length > 0
        $hijacker_redis.hset(redis_keys(:host_translations), row[:ipaddr], row[:hostname])
      end
    end
  end
end

