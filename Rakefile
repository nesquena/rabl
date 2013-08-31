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

# Running integration tests
# rake test:clean
# rake test:setup
# rake test:full

fixture_list = "{padrino_test,sinatra_test,rails2,rails3,rails3_2,rails4}"

desc "Clean up the fixtures being tested by cleaning and installing dependencies"
task "test:clean" do
  Dir[File.dirname(__FILE__) + "/fixtures/#{fixture_list}"].each do |fixture|
    puts "\n*** Cleaning up for #{File.basename(fixture)} tests ***\n"
    Dir.chdir(fixture) { puts `rm Gemfile.lock` }
  end
end

desc "Prepares the fixtures being tested by installing dependencies"
task "test:setup" do
  Dir[File.dirname(__FILE__) + "/fixtures/#{fixture_list}"].each do |fixture|
    puts "\n*** Setting up for #{File.basename(fixture)} tests ***\n"
    `export BUNDLE_GEMFILE="#{fixture}/Gemfile"` if ENV["TRAVIS"]
    Bundler.with_clean_env {
      Dir.chdir(fixture) { puts `mkdir -p tmp/cache; bundle install --gemfile="#{fixture}/Gemfile"`; }
    }
  end
end

desc "Executes the fixture tests"
task "test:fixtures" do
  Dir[File.dirname(__FILE__) + "/fixtures/#{fixture_list}"].each do |fixture|
    puts "\n*** Running tests for #{File.basename(fixture)}... ***\n"
    Bundler.with_clean_env {
      Dir.chdir(fixture) { puts `bundle check; bundle exec rake test:rabl` }
    }
  end
end

task "test:full" => [:test, "test:fixtures"]

desc "Run tests for rabl"
task :default => :test