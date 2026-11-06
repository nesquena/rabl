# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/array/extract_options'
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
require 'rabl/template_cache_key'

if defined?(Rails) && Rails.respond_to?(:version)
  require 'rabl/tracker'
  require 'rabl/digestor'
  require 'rabl/railtie'
end

# Rabl.register!
module Rabl
  # Fiber-local key of the sources read by the render in progress (see Rabl.begin_render_source_cache)
  RENDER_SOURCE_CACHE = :_rabl_render_source_cache
  private_constant :RENDER_SOURCE_CACHE

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
    # Used to cache the contents and paths to various rabl templates, keyed by
    # everything the lookup depends on (the file, the view path and the lookup details)
    # source_cache("users/index", ["path/to/view"], [:json]) { "/full/path/to/template/users/index" }
    def source_cache(file, view_path, lookup = nil)
      # With cache_sources off, a template the collection uses for each item (extends, partial) is
      # still read and resolved once per render rather than once per item. That cache belongs to
      # the render, so a template changed between renders is still read again.
      cache = Rabl.configuration.cache_sources ? (@_source_cache ||= {}) : render_source_cache
      return yield unless cache

      # stores a frozen copy of the key, so later changes to the caller's strings don't reach it
      key = [file, view_path, lookup]
      cache.fetch(key) { cache[frozen_copy(key)] = yield }
    end

    # Resets the RABL source cache
    def reset_source_cache!
      @_source_cache = {}
    end

    # The template sources read so far by the render running in this fiber, if any
    def render_source_cache
      Thread.current[RENDER_SOURCE_CACHE]
    end

    # Internal: Starts collecting the sources the render about to run reads (see source_cache).
    # The render that starts a collection ends it, so a render started inside another collects
    # its own sources for as long as it runs and the render around it reads again afterwards.
    def begin_render_source_cache
      Thread.current[RENDER_SOURCE_CACHE] = {}
    end

    # Internal: Drops the collection the render that returns from it started.
    def end_render_source_cache
      Thread.current[RENDER_SOURCE_CACHE] = nil
    end

    # Returns a copy of value whose Strings and Arrays are frozen, for cache keys that
    # must not change when the caller's objects do
    def frozen_copy(value)
      case value
      when Array  then value.map { |item| frozen_copy(item) }.freeze
      when String then value.frozen? ? value : value.dup.freeze
      else value
      end
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
end
