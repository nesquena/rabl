require 'rabl/version'
require 'rabl/engine'
require 'rabl/builder'

# Rabl.register!
module Rabl
  def self.register!
    require 'rabl/template' if defined?(Rails)
    require 'rabl/register'
  end
end

# Register
if defined?(Padrino)
  require 'padrino-core'
  Padrino.after_load { Rabl.register! }
else
  Rabl.register!
end