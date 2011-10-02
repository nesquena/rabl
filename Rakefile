include Rake::DSL

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/*_test.rb'
  test.warning = true
  test.verbose = true
  test.ruby_opts = ['-rubygems']
end

desc "Run tests for rabl"
task :default => :test

task "test:full" => :test do
  Dir[File.dirname(__FILE__) + "/fixtures/{padrino_test,rails2}"].each do |fixture|
    puts "Running tests for #{File.basename(fixture)}..."
    puts `cd #{fixture}; bundle exec rake test:rabl`
  end
end