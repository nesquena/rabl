require 'json'
require File.expand_path('../teststrap', __FILE__)
require 'rabl/template'
require File.expand_path('../models/ormless', __FILE__)

context "Rabl::MultiBuilder" do
  helper(:multi_builder) { |objects, options| Rabl::MultiBuilder.new(objects, options) }
  helper(:builder)       {                    Rabl::Builder.new({}) }
  helper(:engine)        { |object|           Rabl::Engine.new("").apply(nil, :object => object) }

  context "#initialize" do
    setup do
      Rabl::MultiBuilder.new([], {})
    end

    asserts_topic.assigns :options
    asserts_topic.assigns :data
    asserts_topic.assigns :engine_to_builder
    asserts_topic.assigns :cache_key_to_engine
  end

  context "#to_a" do
    setup do
      Rabl::MultiBuilder.new([], {})
    end

    asserts "returns an array" do
      topic.to_a
    end.is_a?(Array)
  end

  context "#map_cache_key" do
    asserts "maps the cache keys to the engines" do
      mb = multi_builder [], {}
      b = builder
      e = engine User.new
      mock(e).cache_key.returns(['cache key'])
      mb.send(:map_cache_key, e, b)
      mb.instance_variable_get('@cache_key_to_engine').values.include?(e)
    end.equals(true)
  end

  context "#cache_results" do
    setup do
      mb = multi_builder [], {}
      mb.instance_variable_set('@cache_key_to_engine', { 'cache_key' => engine(User.new) })
      mb
    end

    asserts "uses read_multi to find all of the cached values with keys" do
      mock(Rabl.configuration.cache_engine).read_multi('cache_key').returns({})
      topic.send(:cache_results)
    end
  end

  context "map_results_to_builders" do
    asserts "maps the results of cache_results to builder" do
      mb = multi_builder [], {}
      e = engine User.new
      b = builder
      mb.instance_variable_set('@cache_key_to_engine', { 'cache_key' => e })
      mb.instance_variable_set('@engine_to_builder', { e => b })
      b.instance_variable_set('@_engines', [e])

      mock(b).replace_engine(e, '{}')
      mb.send(:map_results_to_builders, { 'cache_key' => '{}' })
    end
  end
end
