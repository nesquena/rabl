require 'active_support'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'

require 'rabl/version'
require 'rabl/helpers'
require 'rabl/sources'
require 'rabl/partials'
require 'rabl/engine'
require 'rabl/builder'
require 'rabl/multi_builder'
require 'rabl/configuration'
require 'rabl/renderer'
require 'rabl/cache_engine'

if defined?(Rails)
  require 'rabl/tracker'  if Rails.version =~ /^[45]/
  require 'rabl/digestor' if Rails.version =~ /^[45]/
  require 'rabl/railtie'  if Rails.version =~ /^[345]/
end

# Rabl.register!
module Rabl
  class << self

    # Initialize RABL within an application
    # Rabl.register!
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

    # Fetches from the source_cache, stores block result in cache if nil
    # Used to cache the contents and paths to various rabl templates
    # source_cache("users/index", "path/to/view") { "/full/path/to/template/users/index" }
    def source_cache(file, view_path, &block)
      return yield unless Rabl.configuration.cache_sources

      cache_key = [file, view_path].compact.join(":")

      @_source_cache ||= {}

      @_source_cache[cache_key] ||= yield
    end

    # Resets the RABL source cache
    def reset_source_cache!
      @_source_cache = {}
    end

    # Renders an object using a specified template within an application.
    # render(@post, 'posts/show', :view_path => "/path/to/app/views")
    def render(object, source, options = {})
      Rabl::Renderer.new(source, object, options).render
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
