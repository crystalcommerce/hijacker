module Hijacker
  class Alias < BaseModel
    belongs_to :database, :class_name => "Hijacker::Database"
  end
end
