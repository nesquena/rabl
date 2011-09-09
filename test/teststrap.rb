$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))

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
  require 'ruby-debug'
  require 'riot'
  require 'riot/rr'
  require 'mongo'
  require 'mongoid'
  require 'tilt'
end


require 'riot'
require 'riot/rr'
require 'tilt'
require File.expand_path('../../lib/rabl',__FILE__)

Riot.pretty_dots

class Riot::Situation
end

class Riot::Context
end

