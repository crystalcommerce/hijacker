module Hijacker
  class BaseModel < ActiveRecord::Base
    establish_connection('root')

    self.abstract_class = true
  end
end
