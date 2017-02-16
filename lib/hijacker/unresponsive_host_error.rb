module Hijacker
  class GenericDbError < StandardError; end
  class UnresponsiveHostError < GenericDbError
    attr_reader :config, :host, :database_name, :original_error, :custom_message

    def initialize(config={}, options={}, custom_message = nil)
      @config          = config
      @host            = config.fetch(:host, nil)
      @database_name   = config.fetch(:database, nil)
      @custom_message  = custom_message
      @original_error  = config.fetch(:original_error, nil)
    end

    def message
      if(custom_message)
        custom_message
      else
        host_identifier = Hijacker.translate_host_ip(host)
        "Database host #{host} (#{host_identifier}) has been marked as unresponsive; unable to connect to #{database_name}"
      end
    end
  end
end
