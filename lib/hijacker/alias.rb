module Hijacker
  class Alias < ActiveRecord::Base
    establish_connection(Hijacker.root_config)

    belongs_to :database, :class_name => "Hijacker::Database"
  end
end
