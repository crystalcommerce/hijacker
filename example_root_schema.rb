ActiveRecord::Schema.define(:version => 1) do
  create_table "databases", :force => true do |t|
    t.string "database"
    t.integer "master_id"
  end

  add_index "databases", "database"
  add_index "databases", "master_id"

  create_table "aliases", :force => true do |t|
    t.integer "database_id"
    t.string "name"
  end

  add_index "aliases", "name"
end
