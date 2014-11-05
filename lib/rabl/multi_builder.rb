module Rabl
  class MultiBuilder
    include Helpers
    
    # Constructs a new MultiBuilder given the data and options.
    # The options will be re-used for all Rabl::Builders.
    # Rabl::MultiBuilder.new([#<User ...>, #<User ...>, ...], { :format => 'json', :child_root => true })   
    def initialize(data, settings = {}, options = {})
      @data                 = data
      @settings             = settings
      @options              = options
      @builders             = []
      @engine_to_builder    = {}
      @cache_key_to_engine  = {}
    end

    # Returns the result of all of the builders as an array
    def to_a
      generate_builders

      if template_cache_configured? && Rabl.configuration.use_read_multi
        map_engines_to_builders
        read_cache_results
        replace_engines_with_cache_results
      end

      result = @builders.map(&:to_hash)
      result = result.map(&:presence).compact if Rabl.configuration.exclude_empty_values_in_collections
      result
    end

    private

    # Creates a builder for each of the data objects
    # and maps the cache keys for each of the engines
    # the builders generated
    def generate_builders
      @builders = @data.map do |object|
        Builder.new(object, @settings, @options)
      end
    end

    def map_engines_to_builders
      @builders.each do |builder|
        builder.engines.each do |engine|
          @engine_to_builder[engine] = builder

          map_cache_key_to_engine(engine)
        end
      end
    end

    # Maps a cache key to an engine
    def map_cache_key_to_engine(engine)
      if cache_key = cache_key_for(engine)
        result_cache_key = ActiveSupport::Cache.expand_cache_key(cache_key, :rabl)
        @cache_key_to_engine[result_cache_key] = engine
        disable_cache_read_on_render(engine)
      end
    end

    def disable_cache_read_on_render(engine)
      case engine
      when Hash
        disable_cache_read_on_render(engine.values.first)
      when Engine
        engine.cache_read_on_render = false
      end
    end

    def cache_key_for(engine)
      case engine
      when Hash
        cache_key_for(engine.values.first)
      when Engine
        engine.cache_key
      end
    end

    # Returns the items that were found in the cache
    def read_cache_results
      @cache_results ||= begin
        mutable_keys = @cache_key_to_engine.keys.map { |k| k.dup }
        if mutable_keys.empty?
          {}
        else
          Rabl.configuration.cache_engine.read_multi(*mutable_keys)
        end
      end
    end

    # Maps the results from the cache back to the builders
    def replace_engines_with_cache_results
      @cache_results.each do |key, value|
        engine = @cache_key_to_engine[key]
        builder = @engine_to_builder[engine]
        builder.replace_engine(engine, value) if value
      end
    end
  end
end
