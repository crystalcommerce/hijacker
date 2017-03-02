# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{dbhijacker}
  s.homepage = "https://github.com/crystalcommerce/hijacker"
  s.version = "0.12.5"

  s.license = "MIT"

  s.authors = ["Michael Xavier", "Donald Plummer", "Woody Peterson", "Marcelo Ribeiro", "David C. Vezzani"]
  s.date = %q{2014-06-18}
  s.description = %q{Allows a single Rails appliation to access many different databases}
  s.email = %q{developers@crystalcommerce.com}

  s.add_dependency("rails", ">= 2.3.14")
  s.add_runtime_dependency("redis", "= 3.0.7")

  s.add_development_dependency "bundler"
  s.add_development_dependency "guard"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "guard-bundler"
  s.add_development_dependency "rake",      ">= 0.9.2"
  s.add_development_dependency "rack-test", ">= 0.6.1"
  s.add_development_dependency "rack",      ">= 1.1.0"
  s.add_development_dependency "rspec",     "~> 2.8"
  s.add_development_dependency "sqlite3",   "~> 1.3.5"
  s.add_development_dependency "test-unit",   "~> 3.0"

  s.extra_rdoc_files = [
    "README.rdoc"
  ]

  s.files = %w{
    Gemfile
    Gemfile.lock
    MIT-LICENSE
    README.rdoc
    Rakefile
    example_root_schema.rb
    dbhijacker.gemspec
    config/redis.yml
    config/settings.yml
    config/initializers/redis.rb
    config/initializers/settings.rb
    lib/configuration/redis_configuration.rb
    lib/dbhijacker.rb
    lib/hijacker/unresponsive_host_error.rb
    lib/hijacker/logging.rb
    lib/hijacker/redis_keys.rb
    lib/hijacker/redis.rb
    lib/hijacker.rb
    lib/hijacker/active_record_ext.rb
    lib/hijacker/alias.rb
    lib/hijacker/base_model.rb
    lib/hijacker/controller_methods.rb
    lib/hijacker/database.rb
    lib/hijacker/host.rb
    lib/hijacker/middleware.rb
    lib/hijacker/request_parser.rb
    spec/hijacker/alias_spec.rb
    spec/hijacker/database_spec.rb
    spec/hijacker/host_spec.rb
    spec/hijacker/middleware_spec.rb
    spec/support/redis_keys_module.rb
    spec/support/alt_host_translations.csv
    spec/support/shared_contexts/rake.rb
    spec/hijacker_spec.rb
    spec/rake_tasks_spec.rb
    spec/spec_helper.rb
    tasks/hijacker_tasks.rake
  }
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.summary = %q{One application, multiple client databases}
  s.test_files = %w{
    spec/hijacker/alias_spec.rb
    spec/hijacker/database_spec.rb
    spec/hijacker/host_spec.rb
    spec/hijacker/middleware_spec.rb
    spec/hijacker/redis_keys_spec.rb
    spec/support/redis_keys_module.rb
    spec/support/alt_host_translations.csv
    spec/support/shared_contexts/rake.rb
    spec/hijacker_spec.rb
    spec/rake_tasks_spec.rb
    spec/spec_helper.rb
  }
end
