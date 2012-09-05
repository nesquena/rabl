ENV["WATCHR"] = "1"
system 'clear'

def run(cmd)
  puts(cmd)
  system cmd
end

def run_test_file(file)
  system('clear')
  run(%Q(ruby -I"lib:test" -rubygems #{file}))
end

def run_all_tests
  system('clear')
  run('rake test')
end

def related_test_files(path)
  Dir['test/**/*.rb'].select { |file| file =~ /#{File.basename(path).split(".").first}_test.rb/ }
end

watch('test/teststrap\.rb') { run_all_tests }
watch('test/(.*).*_test\.rb') { |m| run_test_file(m[0]) }
watch('lib/.*/.*\.rb') { |m| related_test_files(m[0]).map {|tf| run_test_file(tf) } }

# Ctrl-\
Signal.trap 'QUIT' do
  puts " --- Running all tests ---\n\n"
  run_all_tests
end

@interrupted = false

# Ctrl-C
Signal.trap 'INT' do
  if @interrupted then
    @wants_to_quit = true
    abort("\n")
  else
    puts "Interrupt a second time to quit"
    @interrupted = true
    Kernel.sleep 1.5
    # raise Interrupt, nil # let the run loop catch it
    run_all_tests
  end
end
