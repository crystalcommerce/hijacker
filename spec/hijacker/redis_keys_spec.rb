require 'spec_helper'
require 'hijacker/redis_keys'
require 'support/redis_keys_module'

describe Hijacker::RedisKeys do
  let(:key){ 'blah' }
  let(:host){ 'bogus-host' }

  describe "self.rails_env" do
    it "should return the environment descriptor" do
      module Rails; end
      allow(Rails).to receive(:env).and_return 'test'

      expect(Hijacker::RedisKeys.rails_env).to eq 'test'

      Object.send(:remove_const, :Rails)
    end

    it "should return the development environment if Rails is not available" do
      expect(Hijacker::RedisKeys.rails_env).to eq 'development'
    end
  end

  describe "self.redis_key" do
    it "should return the namespaced redis key" do
      ENV['RAILS_ENV'] = 'test'
      expect(Hijacker::RedisKeys.redis_key(key)).to eq('test:blah')
    end

    it "should return the namespaced redis key, defaulting the namespace to development" do
      orig_rails_env = ENV['RAILS_ENV']
      ENV.delete('RAILS_ENV')

      expect(Hijacker::RedisKeys.redis_key(key)).to eq('development:blah')

      ENV['RAILS_ENV'] = orig_rails_env
    end
  end

  describe "instance methods" do
    include RedisKeysModule::Helper

    describe "#redis_keys" do
      it "should return the key for unresponsive_dbhosts" do
        expect(redis_keys(:unresponsive_dbhosts)).to eq("test:hijacker:unresponsive-dbhosts")
      end
    end

    describe "#unresponsive_dbhost_count_threshold" do
      it "should return the defined count threshold for unresponsive_dbhosts" do
        expect(unresponsive_dbhost_count_threshold).to eq(10)
      end

      it "should return the defined count threshold for unresponsive_dbhosts using the value defined in Redis" do
          $hijacker_redis.set(redis_keys(:unresponsive_dbhost_count_threshold), 9)
          expect(unresponsive_dbhost_count_threshold).to eq(9)

          $hijacker_redis.del(redis_keys(:unresponsive_dbhost_count_threshold))
      end
    end

    describe "#unresponsive_dbhost_count" do
      it "should return the number of failed attempts to connect to a given db host" do
        $hijacker_redis.del(redis_keys(:unresponsive_dbhosts))
        
        (1..12).each { increment_unresponsive_dbhost(host) }
        
        expect(unresponsive_dbhost_count(host)).to eq(12)
      end
    end

  end
end

