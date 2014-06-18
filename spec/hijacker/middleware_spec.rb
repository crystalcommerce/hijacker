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

      ActiveRecord::Base.stub(:establish_connection)
    end

    describe "#call" do
      let(:request_env) {{ 'HTTP_X_HIJACKER_DB' => 'sample-db' }}

      def make_request
        get '/', {}, request_env
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
    end
  end
end
