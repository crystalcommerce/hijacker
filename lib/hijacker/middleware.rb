module Hijacker
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if env['HTTP_X_HIJACKER_DB'].present?
        log.debug "HTTP_X_HIJACKER_DB hijacking to #{env['HTTP_X_HIJACKER_DB']}"
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
