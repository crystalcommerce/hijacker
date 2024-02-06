module Hijacker
  class BaseModel < ActiveRecord::Base
    self.primary_key = 'id'

    establish_connection('root')

    self.abstract_class = true
  end
end
