module Hijacker
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if env['HTTP_X_HIJACKER_DB'].present?
        begin
          Hijacker.connect(env['HTTP_X_HIJACKER_DB'])
        rescue Hijacker::InvalidDatabase => e
          return [404, {}, ""]
        end
      end
      @app.call(env)
    end
  end
end
