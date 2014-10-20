module Rabl
  class MultiBuilder
    # Constructs a new MultiBuilder given the data and options.
    # The options will be re-used for all Rabl::Builders.
    # Rabl::MultiBuilder.new([#<User ...>, #<User ...>, ...], { :format => 'json', :child_root => true })   
    def initialize(data, options={})
      @data = data
      @options = options
      @builders = []
      @engine_to_builder = {}
      @cache_key_to_engine = {}
    end

    # Returns the result of all of the builders as an array
    def to_a
      generate_builders
      read_cache_results
      replace_engines_with_cache_results

      @builders.map { |builder| builder.to_hash(@options) }
    end

    private

    # Creates a builder for each of the data objects
    # and maps the cache keys for each of the engines
    # the builders generated
    def generate_builders
      @data.each do |object|
        builder = Rabl::Builder.new(@options)
        builder.build(object, @options.merge(:keep_engines => true))

        @builders << builder

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
      if engine.is_a?(Hash)
        disable_cache_read_on_render(engine.values.first)
      else
        engine.cache_read_on_render = false
      end
    end

    def cache_key_for(engine)
      if engine.is_a?(Hash)
        cache_key_for(engine.values.first)
      else
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
