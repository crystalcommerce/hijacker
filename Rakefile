require 'rake'
require 'rdoc/task'
require 'rubygems/package_task'

desc 'Generate documentation for the hijacker plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Hijacker'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

spec = Gem::Specification.load("dbhijacker.gemspec")
Gem::PackageTask.new(spec) {}

desc "Push latest gem version"
task :release => :gem do
  sh "gem push #{spec.name}-#{spec.version}.gem"
end
