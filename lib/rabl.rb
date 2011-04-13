require 'rabl/version'
require 'rabl/engine'
require 'rabl/builder'

# Rabl.register!
module Rabl
  def self.register!
    require 'rabl/template'
  end
end

# Register
if defined?(Padrino)
  require 'padrino-core'
  Padrino.after_load { Rabl.register! }
elsif defined?(Rails) && Rails.version =~ /^2/
  Rabl.register!
elsif defined?(Rails) && Rails.version =~ /^3/
  Rabl.register!
end