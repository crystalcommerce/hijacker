require "spec_helper"
require_relative "support/shared_contexts/rake"

require_relative '../lib/hijacker/redis_keys'
require 'redis'
require_relative '../config/initializers/redis'

require 'support/redis_keys_module'

# spec/lib/tasks/reports_rake_spec.rb
describe "hijacker:setup_translation_table" do
  include_context "rake"
  include RedisKeysModule::Helper

  it "generates a translation table in Redis using the default csv" do
    $hijacker_redis.del(redis_keys(:host_translations))
    subject.invoke
    translations = $hijacker_redis.hgetall(redis_keys(:host_translations))

    expect(translations.size).to eq(51)
  end

  it "generates a translation table in Redis using a custom csv" do
    $hijacker_redis.del(redis_keys(:host_translations))
    subject.invoke './spec/support/alt_host_translations.csv'
    translations = $hijacker_redis.hgetall(redis_keys(:host_translations))

    expect(translations).to eq({"208.85.150.90"=>"ds1221", "208.85.150.107"=>"ds1222", "208.85.150.126"=>"ds1223"})
  end
end
