require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.warning = true
  test.verbose = true
  test.ruby_opts = ['-rubygems']
end

desc "Run tests for rabl"
task :default => :test
