# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

module Kernel
  def silence_warnings
    with_warnings(nil) { yield }
  end

  def with_warnings(flag)
    old_verbose, $VERBOSE = $VERBOSE, flag
    yield
  ensure
    $VERBOSE = old_verbose
  end
end unless Kernel.respond_to? :silence_warnings

silence_warnings { require 'riot' }

# Riot's own at_exit hook calls `exit(run.success?)` (or exits with the
# status of the last child process), which replaces the status of an
# exception raised while loading the test files: a test file that fails to
# load (LoadError, SyntaxError, a gem that doesn't parse on this Ruby) would
# leave the run green with its tests silently skipped. Run Riot ourselves
# instead, so a load failure keeps its non-zero status and a run that found
# no tests fails too.
Riot.alone!
at_exit do
  if $!.nil? || ($!.is_a?(SystemExit) && $!.success?)
    reporter = Riot.run
    if reporter.passes + reporter.failures + reporter.errors == 0
      $stderr.puts "No tests ran"
      exit(false)
    end
    exit(reporter.success?)
  end
end

silence_warnings do
  require 'riot/rr'
  require 'tilt'
  require 'rabl'
  require 'hashie'
  require File.expand_path('../models/user', __FILE__)
end

if $stdout.tty? then
  Riot.pretty_dots
else
  Riot.dots
  Riot.plain!
end

module RiotTestHelpers
  def char_split(str)
    str.dup.force_encoding("iso-8859-1").split("").sort
  end

  def clean_plist(text)
    text.gsub(%r{<!DOCTYPE plist PUBLIC \"-//([\w\s]+?)//DTD PLIST 1.0//EN\"}, %q{<!DOCTYPE plist PUBLIC \"-//(TEST)//DTD PLIST 1.0//EN\"})
  end
end

class Riot::Situation
  include RiotTestHelpers
end

class Riot::Context
  include RiotTestHelpers
end
