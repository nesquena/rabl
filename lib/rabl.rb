require 'rabl/version'
require 'rabl/engine'
require 'rabl/builder'

# Rabl.register!
module Rabl
  def self.register!
    require 'rabl/template' if defined?(Rails)
    require 'rabl/register_tilt' if defined?(Tilt)
  end
end

Rabl.register!