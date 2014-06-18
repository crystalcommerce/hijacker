require 'spec_helper'
require 'rack/test'

require 'hijacker/middleware'

module Hijacker
  describe Middleware do
    include Rack::Test::Methods

    def app
      Rack::Builder.new do
        use Hijacker::Middleware
        run lambda { |env| [200, { 'blah' => 'blah' }, ["success"]] }
      end
    end

    before(:each) do
      Hijacker.stub(:connect)
    end

    describe "#call" do
      context "When the 'X-Hijacker-DB' header is set" do
        it "connects to the database from the header" do
          Hijacker.should_receive(:connect).with("sample-db")
          get '/', {}, 'HTTP_X_HIJACKER_DB' => 'sample-db'
        end

        it "passes through" do
          resp = get '/', {}, "x-not-db-header" => "something"
          expect(resp.status).to eq(200)
          expect(resp.headers['blah']).to eq("blah")
          expect(resp.body).to eq("success")
        end
      end

      context "When the 'X-Hijacker-DB' header is not set" do
        it "doesn't connect to any database" do
          Hijacker.should_not_receive(:connect)
          get '/',{}, "x-not-db-header" => "something"
        end
      end

      context "database not found" do
        before(:each) do
          Hijacker.stub(:connect).and_raise(Hijacker::InvalidDatabase)
        end

        it "returns a 404" do
          resp = get '/', {}, "HTTP_X_HIJACKER_DB" => "something"
          expect(resp.status).to eq(404)
          expect(resp.body).to eq("Database something not found")
        end

        context "custom missing database handler" do
          def app
            Rack::Builder.new do
              use Hijacker::Middleware, :not_found => ->(env) { [404, {}, "You done goofed"]}
              run lambda { |env| [200, { 'blah' => 'blah' }, ["success"]] }
            end
          end

          it "uses the custom not found handler" do
            resp = get '/', {}, "HTTP_X_HIJACKER_DB" => "something"
            expect(resp.status).to eq(404)
            expect(resp.body).to eq("You done goofed")
          end
        end
      end
    end
  end
end
