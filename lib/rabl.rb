require 'active_support'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/hash/slice'

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
      yield(configuration)
      configuration
    end

    # Returns the configuration options set for RABL
    # Rabl.configuration.include_json_root => false
    def configuration
      @_configuration ||= Configuration.new
    end

    # Resets the RABL configuration back to the defaults.
    def reset_configuration!
      @_configuration = nil
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
