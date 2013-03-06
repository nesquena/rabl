require 'json'
require File.expand_path('../teststrap', __FILE__)
require 'rabl/template'
require File.expand_path('../models/ormless', __FILE__)

context "Rabl::MultiBuilder" do
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
    
  end

  context "#cache_results" do

  end

  context "map_results_to_builders" do

  end
end
