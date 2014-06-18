module Hijacker
  class Middleware
    HEADER_KEY = "HTTP_X_HIJACKER_DB".freeze
    DEFAULT_NOT_FOUND = ->(database, env) {
      [404, {}, ["Database #{database} not found"]]
    }

    attr_reader :not_found

    def initialize(app, options = {})
      @app = app
      @not_found = options.fetch(:not_found, DEFAULT_NOT_FOUND)
    end

    def call(env)
      begin
        Hijacker.connect(*determine_databases(env))
      rescue Hijacker::InvalidDatabase => e
        return not_found.call(e.database, env)
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
