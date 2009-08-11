ActiveRecord::Schema.define(:version => 1) do
  create_table "databases" do |t|
    t.string "database"
  end
  
  create_table "domains" do |t|
    t.string "domain"
    t.integer "database_id"
  end
  
  add_index "domains", ["database_id"]
end