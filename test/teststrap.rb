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

silence_warnings do
  require 'riot'
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
