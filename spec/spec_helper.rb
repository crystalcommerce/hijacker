require 'rubygems'
require 'active_support'
require 'active_support/test_case'
require 'ruby-debug'

require 'active_record'

RAILS_ENV="test"
ENV['RAILS_ENV'] = 'test'
$:.unshift '../lib'
ActiveRecord::Base.configurations = {
  "test" => {
    :adapter => 'sqlite3',
    :database => File.dirname(__FILE__) + "/test_database.sqlite3"
  }
}

ActiveRecord::Base.establish_connection
require File.dirname(__FILE__) + "/../example_root_schema"

require 'hijacker'

RSpec.configure do |config|
  config.before(:each) do
    Hijacker::Database.delete_all
    Hijacker::Alias.delete_all
  end
end
