# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{dbhijacker}
  s.homepage = "https://github.com/crystalcommerce/hijacker"
  s.version = "0.4.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Michael Xavier", "Donald Plummer", "Woody Peterson"]
  s.date = %q{2012-03-21}
  s.description = %q{Allows a single Rails appliation to access many different databases}
  s.email = %q{developers@crystalcommerce.com}
  s.add_dependency("rails", "~>2.3.14")
  s.add_development_dependency("rake", "~>0.9.2")
  s.add_development_dependency("rack-test", "~>0.6.1")
  s.add_development_dependency("rack", "~>1.1.0")
  s.add_development_dependency("rspec", "~>2.8.0")
  s.add_development_dependency("sqlite3", "~>1.3.5")
  s.add_development_dependency("ruby-debug", "~>0.10.4")
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = %w{
    Gemfile
    Gemfile.lock
    MIT-LICENSE
    README.rdoc
    Rakefile
    VERSION
    example_root_schema.rb
    hijacker.gemspec
    init.rb
    install.rb
    lib/dbhijacker.rb
    lib/hijacker.rb
    lib/hijacker/active_record_ext.rb
    lib/hijacker/alias.rb
    lib/hijacker/controller_methods.rb
    lib/hijacker/database.rb
    lib/hijacker/host.rb
    lib/hijacker/middleware.rb
    spec/hijacker/alias_spec.rb
    spec/hijacker/database_spec.rb
    spec/hijacker/host_spec.rb
    spec/hijacker/middleware_spec.rb
    spec/hijacker_spec.rb
    spec/spec_helper.rb
    tasks/hijacker_tasks.rake
    uninstall.rb
  }
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.8.15}
  s.summary = %q{One application, multiple client databases}
  s.test_files = %w{
    spec/hijacker/alias_spec.rb
    spec/hijacker/database_spec.rb
    spec/hijacker/host_spec.rb
    spec/hijacker/middleware_spec.rb
    spec/hijacker_spec.rb
    spec/spec_helper.rb
  }

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

