require 'rubygems'
require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'ruby-debug'

require 'active_record'

$:.unshift '../lib'
require 'hijacker'

RAILS_ENV="test"

ActiveRecord::Base.configurations = {
  "test" => {
    :adapter => 'sqlite3',
    :database => File.dirname(__FILE__) + "/test_database.sqlite3"
  }
}
ActiveRecord::Base.establish_connection
require File.dirname(__FILE__) + "/../example_root_schema"

require File.dirname(__FILE__) + '/../lib/hijacker/database.rb'
