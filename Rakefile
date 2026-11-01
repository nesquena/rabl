include Rake::DSL

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/*_test.rb'
  test.warning = true
  test.verbose = true
  if RUBY_VERSION < "1.9.0"
    # -rubygems isn't needed as of 1.9, and is gone as of 2.5
    # https://github.com/ruby/ruby/blob/v2_5_0/NEWS#stdlib-compatibility-issues-excluding-feature-bug-fixes
    test.ruby_opts = ['-rubygems']
  end
end

desc "Run tests for rabl"
task :default => :test
