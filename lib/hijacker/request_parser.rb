require 'rack/request'

module Hijacker
  class RequestParser
    attr_reader :host

    def self.from_env(env)
      request = Rack::Request.new(env)
      from_request(request)
    end

    def self.from_request(request)
      new(request.host)
    end

    def initialize(host)
      @host = host
    end

    def determine_databases
      raise Hijacker::UnparseableURL, "cannot parse '#{host}'" if client.nil?

      Hijacker::Database.find_master_and_sister_for(client)
    end

  private

    def client
      @client ||= do_hijacking? ? client_from_domain_pattern : base_client
    end

    def client_from_domain_pattern
      Hijacker.config.
        fetch(:domain_patterns).
        map {|pattern| host.scan(pattern).flatten.first}.
        compact.
        first
    end

    def base_client
      ActiveRecord::Base.configurations.fetch(Rails.env).fetch('database')
    end

    def do_hijacking?
      Hijacker.do_hijacking?
    end
  end
end
