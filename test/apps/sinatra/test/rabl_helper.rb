ENV['RACK_ENV'] = 'test'
require_relative '../app'
require_relative 'rabl_helper_common'
require 'minitest/autorun'

class RablAppTest < Minitest::Test
  include RablAppTestHelpers

  def app
    RablSinatraApp
  end

  # Turns on caching, with an empty store, for the block
  def with_caching
    engine, caching = Rabl.configuration.cache_engine, Rabl.configuration.perform_caching
    Rabl.configuration.cache_engine = Rabl::CacheEngine.new
    Rabl.configuration.perform_caching = true
    yield
  ensure
    Rabl.configuration.cache_engine = engine
    Rabl.configuration.perform_caching = caching
  end
end
