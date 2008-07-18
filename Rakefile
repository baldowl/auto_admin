require 'rake'
require 'rake/rdoctask'

desc 'Default: generate documentation.'
task :default => :rdoc

desc 'Generate documentation for the auto_admin plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'AutoAdmin'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
