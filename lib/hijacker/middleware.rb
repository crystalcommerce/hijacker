module Hijacker
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if env['x-hijacker-db']
        Hijacker.connect(env['x-hijacker-db'])
      end
      @app.call(env)
    end
  end
end
