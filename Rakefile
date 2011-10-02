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

task "test:full" => :test do
  Dir[File.dirname(__FILE__) + "/fixtures/{padrino_test,sinatra_test,rails2,rails3}"].each do |fixture|
    puts "\n*** Running tests for #{File.basename(fixture)}... ***\n"
    `cd #{fixture}; bundle install;`
    `export BUNDLE_GEMFILE=#{fixture}/Gemfile` if ENV['TRAVIS']
    puts `cd #{fixture}; bundle exec rake test:rabl`
  end
end

desc "Run tests for rabl"
task :default => :test