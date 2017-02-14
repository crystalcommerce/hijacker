# spec/support/shared_contexts/rake.rb
require "rake"

shared_context "rake" do
  let(:rake)      { Rake::Application.new }
  let(:task_name) { self.class.top_level_description }
  let(:rakefile_path) { "Rakefile" }
  subject         { rake[task_name] }

  before do
    Rake.application = rake
    rake.init
    rake.load_rakefile
    #Rake.application.rake_require( '/Users/davidvezzani/reliacode/crystal_commerce/hijacker/Rakefile' )

    #Rake::Task.define_task(:environment)
  end
end
