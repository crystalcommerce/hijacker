module Hijacker
  module Logging
    def logger=(logger)
      @logger = logger
    end

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = self.name
      end
    end
  end
end
