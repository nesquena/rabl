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

desc "Prepares the fixtures for being tested by installing dependencies"
task "test:setup" do
  Dir[File.dirname(__FILE__) + "/fixtures/{padrino_test,sinatra_test,rails2,rails3}"].each do |fixture|
    puts "\n*** Setting up for #{File.basename(fixture)} tests ***\n"
    `export BUNDLE_GEMFILE=#{fixture}/Gemfile` if ENV['TRAVIS']
    puts `cd #{fixture}; bundle install;`
  end
end

desc "Executes the fixture tests"
task "test:fixtures" do
  Dir[File.dirname(__FILE__) + "/fixtures/{padrino_test,sinatra_test,rails2,rails3}"].each do |fixture|
    puts "\n*** Running tests for #{File.basename(fixture)}... ***\n"
    puts `cd #{fixture}; bundle check; bundle exec rake test:rabl`
  end
end

task "test:full" => [:test, "test:fixtures"]

desc "Run tests for rabl"
task :default => :test