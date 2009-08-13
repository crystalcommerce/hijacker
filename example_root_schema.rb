ActiveRecord::Schema.define(:version => 1) do
  create_table "databases" do |t|
    t.string "database"
    t.integer "master_id"
  end
  
  add_index "databases", "master_id"
end