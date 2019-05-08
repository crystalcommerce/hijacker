require 'active_support/core_ext/hash/indifferent_access'

module Hijacker
  path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'settings.yml'))

  APP_CONFIG = YAML.load_file(path)['defaults'].with_indifferent_access

  APP_CONFIG.each_pair do |key, value|
    key.freeze
    value.freeze
  end.freeze
end
