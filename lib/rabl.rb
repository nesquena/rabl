require 'rabl/version'
require 'rabl/helpers'
require 'rabl/engine'
require 'rabl/builder'
require 'rabl/configuration'
require 'rabl/railtie' if defined?(Rails) && Rails.version =~ /^3/

# Rabl.register!
module Rabl
  class << self
    def register!
      require 'rabl/template'
    end

    # Yields a RABL configuration block
    # Rabl.configure do |config|
    #  config.include_json_root     = false
    #  config.enable_json_callbacks = true
    # end
    def configure(&block)
      yield(self.configuration)
    end

    # Returns the configuration options set for RABL
    # Rabl.configuration.include_json_root => false
    def configuration
      @_configuration ||= Configuration.new
    end
  end
end

# Register
if defined?(Padrino)
  require 'padrino-core'
  Padrino.after_load { Rabl.register! }
elsif defined?(Rails) && Rails.version =~ /^2/
  Rabl.register!
end
