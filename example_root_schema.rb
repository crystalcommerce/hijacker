ActiveRecord::Schema.define(:version => 1) do
  create_table "databases", :force => true do |t|
    t.string "database"
    t.integer "master_id"
  end
  
  add_index "databases", "master_id"
end
