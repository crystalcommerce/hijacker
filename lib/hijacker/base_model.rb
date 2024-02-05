module Hijacker
  class BaseModel < ActiveRecord::Base
    establish_connection('root')

    self.primary_key = 'id'
    self.abstract_class = true
  end
end
