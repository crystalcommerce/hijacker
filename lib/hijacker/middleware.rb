module Hijacker
  class Middleware
    HEADER_KEY = "HTTP_X_HIJACKER_DB".freeze
    DEFAULT_NOT_FOUND = ->(env) {
      [404, {}, ["Database #{get_database(env)} not found"]]
    }

    attr_reader :not_found

    def initialize(app, options = {})
      @app = app
      @not_found = options.fetch(:not_found, DEFAULT_NOT_FOUND)
    end

    def call(env)
      if env[HEADER_KEY].present?
        begin
          Hijacker.connect(self.class.get_database(env))
        rescue Hijacker::InvalidDatabase
          return not_found.call(env)
        end
      end

      @app.call(env)
    end

  private

    def self.get_database(env)
      env[HEADER_KEY]
    end
  end
end
