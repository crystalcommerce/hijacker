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
    translations = $hijacker_redis.smembers(redis_keys(:host_translations))
  
    expect(translations.size).to eq(42)
  end

  it "generates a translation table in Redis using a custom csv", focus: true do
    $hijacker_redis.del(redis_keys(:host_translations))
    subject.invoke nil, './spec/support/alt_host_translations.csv'
    translations = $hijacker_redis.smembers(redis_keys(:host_translations))

    expect(translations.sort).to eq(["208.85.150.90", "208.85.150.107", "208.85.150.126"].sort)
  end

  it "generates a translation table in redis with specified configuration", focus: true do
    $hijacker_redis.del(redis_keys(:host_translations))
    subject.invoke "{\"host\":\"localhost\",\"port\":6379,\"db\":0}", './spec/support/alt_host_translations.csv'
    translations = $hijacker_redis.smembers(redis_keys(:host_translations))

    expect(translations.sort).to eq(["208.85.150.90", "208.85.150.107", "208.85.150.126"].sort)
  end

  it "generates a translation table in Redis using a custom csv" do
    $hijacker_redis.del(redis_keys(:host_translations))
    subject.invoke nil, './spec/support/alt_host_translations.csv'
    translations = redis_translation_table

    expect(translations).to eq({"208.85.150.90"=>{"hostname"=>"ds1221", "hostid"=>""}, "208.85.150.107"=>{"hostname"=>"ds1222", "hostid"=>""}, "208.85.150.126"=>{"hostname"=>"ds1223", "hostid"=>""}})
  end
end
