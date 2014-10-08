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
  require File.expand_path('../models/user', __FILE__)
end

Riot.pretty_dots

class Riot::Situation
  def char_split(str)
    str.force_encoding("iso-8859-1").split("").sort
  end
end

class Riot::Context
  def char_split(str)
    str.force_encoding("iso-8859-1").split("").sort
  end
end
