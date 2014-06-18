require 'rubygems'
require 'active_support'
require 'active_support/test_case'
require 'active_record'

RAILS_ENV = "test"
ENV['RAILS_ENV'] = 'test'

$:.unshift '../lib'

ActiveRecord::Base.configurations = {
  "root" => {
    :adapter => 'sqlite3',
    :database => File.dirname(__FILE__) + "/test_database.sqlite3"
  },
  "test" => {
    :adapter => 'sqlite3',
    :database => File.dirname(__FILE__) + "/test_database.sqlite3"
  }
}

ActiveRecord::Base.establish_connection(:test)
require File.dirname(__FILE__) + "/../example_root_schema"

require 'hijacker'

RSpec.configure do |config|
  config.before(:each) do
    Hijacker::Database.delete_all
    Hijacker::Alias.delete_all
  end
end
