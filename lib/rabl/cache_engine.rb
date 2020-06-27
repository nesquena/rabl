# Defines the default cache engine for RABL when caching is invoked for a template.
# You can define your own caching engines by creating an object that responds to fetch and
# setting the configuration option:
#
#     config.cache_engine = AdvancedCacheEngine.new
#

class LRU < Hash
  attr_accessor :max_size

  def initialize
    super
    self.max_size = 100_000
  end

  def []= k,v
    r = super
    limit_size
    r
  end

  def limit_size
    if size > max_size then
      delete keys.shift while size > max_size
    end
  end
end

module Rabl
  class CacheEngine
    def initialize
      unless defined?(Rails)
        @cache = LRU.new
      end
    end


    # Fetch given a key and options and a fallback block attempts to find the key in the cache
    # and stores the block result in there if no key is found.
    #
    # cache = Rabl::CacheEngine.new; cache.fetch("some_key") { "fallback data" }
    #
    def fetch(key, cache_options, &block)
      if defined?(Rails)
        Rails.cache.fetch(key, cache_options, &block)
      else
        @cache[key] ||= yield
      end
    end

    def write(key, value, options = {})
      if defined?(Rails)
        Rails.cache.write(key, value, options)
      else
        @cache[key] = yield
      end
    end

    def read_multi(*keys)
      options = keys.extract_options!
      if defined?(Rails)
        Rails.cache.read_multi(*keys, options)
      else
        keys.inject({}) { |hash, key| hash[key] = nil; hash }
      end
    end
  end
end
