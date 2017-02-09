require 'active_support/core_ext/hash/indifferent_access'

module Hijacker
  path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'settings.yml'))

  env = if defined?(Rails)
          Rails.env
        else
          ENV.fetch('RAILS_ENV', 'development')
        end
  
  APP_CONFIG = YAML.load_file(path)[env].with_indifferent_access

  APP_CONFIG.each_pair do |key, value|
    key.freeze
    value.freeze
  end.freeze
end

