# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require File.expand_path('../teststrap', __FILE__)

# rabl loads the same Rails integrations under every Rails version it supports, and newer ones:
# it no longer reads Rails.version, and these runs keep it that way. Each version runs in its own
# process, as rabl loads them when it is required, with stand-ins for the parts of Rails they use:
# the railtie runs its initializer and the action_view load hooks, as Rails does.
context "Rabl's Rails integration" do
  helper(:loaded_under) do |rails_version|
    script = <<-'RUBY'
      rails_version, stubs = ARGV
      $LOAD_PATH.unshift(stubs) # empty action_view and action_view/dependency_tracker files
      require 'active_support'
      require 'active_support/core_ext/class/attribute'

      module Rails
        class Railtie
          def self.initializers; @initializers ||= []; end
          def self.initializer(_name, &block); initializers << block; end
        end
      end
      Rails.define_singleton_method(:version) { rails_version }
      module ActionView
        module Rendering; end
        class Digestor; end
        class Template
          module Handlers; end
          def self.register_template_handler(name, handler); $handler = [name, handler]; end
        end
        module DependencyTracker
          def self.register_tracker(name, tracker); $tracker = [name, tracker]; end
        end
      end

      require 'rabl'
      Rabl::Railtie.initializers.each { |initializer| initializer.call(nil) } if defined?(Rabl::Railtie)
      ActiveSupport.run_load_hooks(:action_view)

      handler = $handler && "#{$handler[0]} handler taking #{$handler[1].method(:call).arity} arguments"
      tracker = $tracker && "#{$tracker[0]} tracker #{$tracker[1]}"
      puts [("railtie" if defined?(Rabl::Railtie)), ("digestor" if defined?(Rabl::Digestor)), handler, tracker].compact.join(", ")
    RUBY
    Dir.mktmpdir do |stubs|
      FileUtils.mkdir_p(File.join(stubs, 'action_view'))
      FileUtils.touch([File.join(stubs, 'action_view.rb'), File.join(stubs, 'action_view', 'dependency_tracker.rb')])
      lib = File.expand_path('../../lib', __FILE__)
      IO.popen([RbConfig.ruby, "-I", lib, "-e", script, rails_version, stubs], :err => [:child, :out], &:read).strip
    end
  end

  %w(6.1.0 8.1.0 9.0.0 10.0.0).each do |rails_version|
    asserts("Rails #{rails_version} loads the railtie, the digestor, the tracker and the handler") do
      loaded_under(rails_version)
    end.equals "railtie, digestor, rabl handler taking 2 arguments, rabl tracker Rabl::Tracker"
  end
end
