ActiveRecord::Schema.define(:version => 2) do
  create_table "databases", :force => true do |t|
    t.string "database"
    t.integer "master_id"
    t.integer "host_id"
  end

  add_index "databases", "database", :unique => true
  add_index "databases", "master_id"

  create_table "aliases", :force => true do |t|
    t.integer "database_id"
    t.string "name"
  end

  add_index "aliases", "name", :unique => true

  create_table "hosts", :force => true do |t|
    t.string "hostname"
    t.string "common_hostname"
    t.integer "port", :default => 3306
  end
end
