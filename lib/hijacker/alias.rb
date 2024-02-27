module Hijacker
  class Alias < BaseModel
    self.primary_key = :id
    self.table_name = 'aliases'
    attr_accessible :database_id, :name
    
    belongs_to :database, :class_name => "Hijacker::Database"
  end
end
