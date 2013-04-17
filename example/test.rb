#!/usr/bin/env ruby
require 'bundler/setup'
require 'active_record'
require 'logging'

RAILS_ENV = "test"
$logger ||= Logging.logger(STDOUT)
ActiveRecord::Base.logger = $logger
ActiveRecord::Base.configurations = YAML.load_file("database.yml")
ActiveRecord::Base.establish_connection

require 'dbhijacker'
Hijacker.config = {
  :hosted_environments => %w(),
  :domain_patterns => [],
  :after_hijack => Proc.new { },
  :sister_site_models => %w()
}


class Product < ActiveRecord::Base
end

class HijackerMultiHostTest
  attr_reader :root_server_port, :root_database_name

  def initialize(opts = {})
    @root_database_name = opts.fetch(:root_database_name, "dbhijacker_root")
    @root_server_port = opts.fetch(:root_server_port, 3311)
  end

  def run
    clear_products

    create_products

    verify_products
  end

private
  def clear_products
    Hijacker::Database.connect_each do |db|
      Product.delete_all
    end
  end

  def create_products
    databases_paired_with_product_names.each do |(database, product_name)|
      Hijacker.connect(database)
      create_product(product_name)
    end
  end

  def create_product(name)
    Product.create!(:name => name, :price_cents => 100, :quantity => 1)
  end

  def verify_products
    databases_paired_with_product_names.each do |(database, product_name)|
      Hijacker.connect(database)
      all_products = Product.all(:select => "name").map(&:name)
      unless all_products == [product_name]
        raise "Expected #{database} to have only #{product_name} but got #{all_products.join(", ")}"
      end
    end
  end

  def databases_paired_with_product_names
    @databases_paired_with_product_names ||= Hijacker::Database.all.map do |h|
      [h.database, "product for #{h.database}"]
    end
  end
end

HijackerMultiHostTest.new.run
