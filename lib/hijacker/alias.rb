module Hijacker
  class Alias < BaseModel
    self.primary_key = :id
    attr_accessible :database_id, :name
    
    belongs_to :database, :class_name => "Hijacker::Database"
  end
end
