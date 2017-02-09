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

    let!(:host) { Hijacker::Host.create!(:hostname => "localhost") }
    let!(:master) { Hijacker::Database.create!(:database => "sample-db", :host => host) }
    let!(:foo) { Hijacker::Database.create!(:database => "foo", :host => host) }

    before(:each) do
      Hijacker.config = {
       :hosted_environments => %w[test],
       :domain_patterns => [
         /^(.+)-admin\.crystalcommerce\.com/
       ],
       :sister_site_models => []
      }

    end

    describe "#call" do
      let(:request_env) {{ 'HTTP_X_HIJACKER_DB' => 'sample-db' }}

      def make_request
        get '/', {}, request_env
      end

      context "When Database connection fails" do
        it "connection automatically recovers" do
          make_request
          expect(Hijacker.current_client).to eq('sample-db')
          expect(ActiveRecord::Base.connected?).to be true
          ActiveRecord::Base.remove_connection
          expect(ActiveRecord::Base.connected?).to be nil
          resp = make_request
          expect(ActiveRecord::Base.connected?).to be true
          expect(Hijacker.current_client).to eq('sample-db')
          expect(resp.status).to eq(200)

        end
      end

      context "When the 'X-Hijacker-DB' header is set" do
        it "connects to the database from the header" do
          make_request
          expect(Hijacker.current_client).to eq('sample-db')
        end

        it "passes through" do
          resp = make_request
          expect(resp.status).to eq(200)
          expect(resp.headers['blah']).to eq("blah")
          expect(resp.body).to eq("success")
        end
      end

      context "When the 'X-Hijacker-DB' header is not set" do
        let(:request_env) do
          {
           "HTTP_HOST" => "foo-admin.crystalcommerce.com"
          }
        end

        it "parses the host from the request and connects" do
          make_request
          expect(Hijacker.current_client).to eq("foo")
        end

        it "passes through" do
          resp = make_request
          expect(resp.status).to eq(200)
          expect(resp.headers['blah']).to eq("blah")
          expect(resp.body).to eq("success")
        end


        context "databases could not be determined" do
          let(:request_env) do
            {
             "HTTP_HOST" => "bogus-admin.crystalcommerce.com"
            }
          end

          it "returns a 404" do
            resp = make_request
            expect(resp.status).to eq(404)
            expect(resp.body).to eq("Database bogus not found")
          end
        end
      end

      context "unparseable URL" do
        let(:request_env) do
          {
           "HTTP_HOST" => "(>'-'>)"
          }
        end

        it "returns a 404" do
          resp = make_request
          expect(resp.status).to eq(404)
          expect(resp.body).to eq("cannot parse '(>'-'>)'")
        end

        context "custom bad url handler" do
          def app
            Rack::Builder.new do
              use Hijacker::Middleware, :bad_url => ->(message, env) { [404, {}, "You done goofed, #{message}"]}
              run lambda { |env| [200, { 'blah' => 'blah' }, ["success"]] }
            end
          end

          it "uses the custom not found handler" do
            resp = make_request
            expect(resp.status).to eq(404)
            expect(resp.body).to eq("You done goofed, cannot parse '(>'-'>)'")
          end
        end
      end

      context "database not found" do
        let(:request_env) {{ 'HTTP_X_HIJACKER_DB' => 'bogus' }}

        it "returns a 404" do
          resp = make_request
          expect(resp.status).to eq(404)
          expect(resp.body).to eq("Database bogus not found")
        end


        context "custom missing database handler" do
          def app
            Rack::Builder.new do
              use Hijacker::Middleware, :not_found => ->(database, env) { [404, {}, "You done goofed, #{database}"]}
              run lambda { |env| [200, { 'blah' => 'blah' }, ["success"]] }
            end
          end

          it "uses the custom not found handler" do
            resp = make_request
            expect(resp.status).to eq(404)
            expect(resp.body).to eq("You done goofed, bogus")
          end
        end
      end

      context "associated db host responsiveness" do
        before do
          allow(Hijacker).to receive(:dbhost_available?).and_return false
          allow(Hijacker).to receive(:translate_host_ip).and_return("ds9999")

          $hijacker_redis.del(Hijacker.redis_key(Hijacker::REDIS_UNRESPONSIVE_DBHOST_COUNT_THRESHOLD_KEY)) if Hijacker.rails_env == 'test'
        end

        it "returns a 502" do
          resp = make_request
          expect(resp.status).to eq(502)
          expect(resp.body).to eq("Database host localhost (ds9999) has been marked as unresponsive; unable to connect to foo")
        end

        context "custom bad url handler" do
          def app
            Rack::Builder.new do
              use Hijacker::Middleware, :unresponsive_host => ->(message, env) { [502, {}, "The db host is unresponsive.  #{message}"]}
              run lambda { |env| [200, { 'blah' => 'blah' }, ["success"]] }
            end
          end

          it "uses the custom unresponsive host handler" do
            resp = make_request
            expect(resp.status).to eq(502)
            expect(resp.body).to eq("The db host is unresponsive.  Database host localhost (ds9999) has been marked as unresponsive; unable to connect to foo")
          end
        end
      end
    end
  end
end
