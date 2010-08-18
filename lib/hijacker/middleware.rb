module Hijacker
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if env['X-Hijacker-DB']
        Hijacker.connect(env['X-Hijacker-DB'])
      end
      @app.call(env)
    end
  end
end
