require 'spec_helper'
require 'rack/test'

require 'hijacker/middleware'

module Hijacker
  describe Middleware do
    include Rack::Test::Methods

    def app
      Rack::Builder.new do
        use Hijacker::Middleware
        run lambda { |env| [200, { 'blah' => 'blah' }, "success"] }
      end
    end

    describe "#call" do
      context "When the 'X-Hijacker-DB' header is set" do
        it "connects to the database from the header" do
          Hijacker.should_receive(:connect).with("sample-db")
          get '/',{}, 'X-Hijacker-DB' => 'sample-db'
        end
      end

      context "When the 'X-Hijacker-DB' header is not set" do
        it "doesn't connect to any database" do
          Hijacker.should_not_receive(:connect)
          get '/',{}, "x-not-db-header" => "something"
        end
      end
    end
  end
end
