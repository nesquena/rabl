require_relative 'test_helper'
require_relative 'rabl_helper_common'

class RablAppTest < Minitest::Test
  include RablAppTestHelpers

  def app
    Rails.application
  end

  # Turns on caching, with an empty store, for the block
  def with_caching
    store, caching = Rails.cache, ActionController::Base.perform_caching
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActionController::Base.perform_caching = true
    yield
  ensure
    Rails.cache = store
    ActionController::Base.perform_caching = caching
  end
end
