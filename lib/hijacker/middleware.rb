module Hijacker
  class Middleware
    HEADER_KEY = "HTTP_X_HIJACKER_DB".freeze
    DEFAULT_NOT_FOUND = ->(database, env) {
      [404, {}, ["Database #{database} not found"]]
    }
    DEFAULT_BAD_URL = ->(message, env) {
      [404, {}, [message]]
    }

    attr_reader :not_found, :bad_url

    def initialize(app, options = {})
      options = options.dup
      @app = app
      @not_found = options.delete(:not_found) || DEFAULT_NOT_FOUND
      @bad_url   = options.delete(:bad_url)   || DEFAULT_BAD_URL

      unless options.blank?
        raise "Unknown Hijacker::Middleware options #{options.keys.join(",")}"
      end
    end

    def call(env)
      begin
        Hijacker.connect(*determine_databases(env))
      rescue Hijacker::InvalidDatabase => e
        return not_found.call(e.database, env)
      rescue Hijacker::UnparseableURL => e
        return bad_url.call(e.message, env)
      end

      @app.call(env)
    end

  private

    def determine_databases(env)
      if client = env[HEADER_KEY]
        Hijacker::Database.find_master_and_sister_for(client)
      else
        RequestParser.new(env).determine_databases
      end
    end
  end
end
