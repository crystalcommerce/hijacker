#!/usr/bin/env ruby
require 'bundler/setup'
require 'active_record'
require 'logging'

class CreateDatabase
  attr_reader :port, :name

  def initialize(port, name)
    @port = port
    @name = name
  end

  def create
    establish_connection
    create_database
    load_schema
  end

  def create_database
    ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS #{name}")
  end

  def establish_connection
    $logger.debug "Establishing ActiveRecord connection to database #{name} on port #{port}"
    ActiveRecord::Base.establish_connection(adapter: "mysql2",
                                            host: "localhost",
                                            port: port,
                                            database: name,
                                            username: 'root')
  end
end

class RootDatabase < CreateDatabase
  def create(names_ports)
    super()
    insert_client_databases(names_ports)
  end

  def insert_client_databases(names_ports)
    ActiveRecord::Base.configurations = {
      "root" => {
        adapter: "mysql2",
        database: name,
        port: port,
        user: "root"
      }
    }
    require 'dbhijacker'
    names_ports.each do |(name, port)|
      host = Hijacker::Host.find_or_initialize_by_hostname_and_port("localhost", port)
      host.save!
      Hijacker::Database.create!(database: name, host: host)
    end
  end

  def load_schema
    ActiveRecord::Migration.create_table "databases", :force => true do |t|
      t.string "database"
      t.integer "master_id"
      t.integer "host_id"
    end

    ActiveRecord::Migration.add_index "databases", "database", unique: true
    ActiveRecord::Migration.add_index "databases", "master_id"

    ActiveRecord::Migration.create_table "aliases", :force => true do |t|
      t.integer "database_id"
      t.string "name"
    end

    ActiveRecord::Migration.add_index "aliases", "name"

    ActiveRecord::Migration.create_table "hosts", :force => true do |t|
      t.string "hostname"
      t.integer "port"
    end
  end
end

class CreateClientDatabase < CreateDatabase
  def load_schema
    ActiveRecord::Migration.create_table "products", :force => true do |t|
      t.string "name"
      t.integer "price_cents"
      t.integer "quantity"
    end
  end
end

class CreateDatabases
  attr_reader :root_server_port, :secondary_server_ports, :client_names,
    :root_database_name

  def initialize(opts = {})
    root_database_config = YAML.load_file("database.yml")['root']
    @root_database_name = root_database_config['database']
    @root_server_port = root_database_config['port']
    @secondary_server_ports = opts.fetch(:secondary_server_ports, [3312, 3313])
    @client_names = opts.fetch(:client_names, (1..6).map {|n| "store#{n}"})
  end

  def run
    names_paired_with_ports = client_names.zip([root_server_port, *secondary_server_ports].cycle)

    create_root_database(names_paired_with_ports)

    names_paired_with_ports.each do |(name, port)|
      create_client_database(port, name)
    end
  end

  def create_root_database(names_paired_with_ports)
    root_database.create(names_paired_with_ports)
  end

  def root_database
    @root_database ||= RootDatabase.new(root_server_port, root_database_name)
  end

  def create_client_database(port, name)
    CreateClientDatabase.new(port, name).create
  end
end

$logger ||= Logging.logger(STDOUT)
ActiveRecord::Base.logger = $logger
CreateDatabases.new.run
