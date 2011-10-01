require 'rake/testtask'

test_tasks = Dir['test/*/'].map { |d| File.basename(d) }

test_tasks.each do |folder|
  Rake::TestTask.new("test:#{folder}") do |test|
    test.pattern = "test/#{folder}/**/*_test.rb"
    test.verbose = true
  end
end

desc "Run application test suite"
task 'test' => test_tasks.map { |f| "test:#{f}" }
