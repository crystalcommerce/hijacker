require 'rake'
require 'rake/rdoctask'


desc 'Generate documentation for the hijacker plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Hijacker'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "hijacker"
    gemspec.summary = "One application, multiple client databases"
    gemspec.description = "Allows a single Rails appliation to access many different databases"
    gemspec.email = "woody@crystalcommerce.com"
    gemspec.authors = ["Woody Peterson"]
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install jeweler"
end
