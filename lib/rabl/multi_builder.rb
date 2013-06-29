module Rabl
  class MultiBuilder
    # Constructs a new MultiBuilder given the data and options.
    # The options will be re-used for all Rabl::Builders.
    # Rabl::Multibuilder.new([#<User ...>, #<User ...>, ...], { :format => 'json', :child_root => true })   
    def initialize(data, options={})
      @data = data
      @options = options
      @engineless_builders = []
      @engine_to_builder = {}
      @cache_key_to_engine = {}
    end

    # Returns the result of all of the builders as an array
    def to_a
      generate_builders
      result_hash = cache_results
      map_results_to_builders(result_hash)

      @engine_to_builder.values.map { |builder| builder.to_hash(@options) }.concat(@engineless_builders)
    end

    private

    # Creates a builder for each of the data objects
    # and maps the cache keys for each of the engines
    # the builders generated
    def generate_builders
      @data.each do |object|
        builder = Rabl::Builder.new(@options)
        builder.build(object, @options.merge(:keep_engines => true))

        builder.engines.each do |engine|
          map_cache_key(engine, builder)
        end

        @engineless_builders << builder.to_hash(@options) unless builder.engines.any?
      end
    end

    # Maps an engine to a cache key and the engine to a builder
    def map_cache_key(engine, builder)
      @engine_to_builder[engine] = builder
      
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
    def cache_results
      mutable_keys = @cache_key_to_engine.keys.map { |k| k.dup }
      return {} if mutable_keys.empty?

      Rabl.configuration.cache_engine.read_multi(*mutable_keys)
    end

    # Maps the results from the cache back to the builders
    def map_results_to_builders(result_hash)
      result_hash.each do |key, value|
        engine = @cache_key_to_engine[key]
        builder = @engine_to_builder[engine]
        builder.replace_engine(engine, value) if value
      end
    end
  end
end
