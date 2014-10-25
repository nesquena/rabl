# Defines the default cache engine for RABL when caching is invoked for a template.
# You can define your own caching engines by creating an object that responds to fetch and
# setting the configuration option:
#
#     config.cache_engine = AdvancedCacheEngine.new
#

module Rabl
  class CacheEngine

    # Fetch given a key and options and a fallback block attempts to find the key in the cache
    # and stores the block result in there if no key is found.
    #
    # cache = Rabl::CacheEngine.new; cache.fetch("some_key") { "fallback data" }
    #
    def fetch(key, cache_options, &block)
      if defined?(Rails)
        Rails.cache.fetch(key, cache_options, &block)
      else
        yield
      end
    end

    def write(key, value, options = {})
      if defined?(Rails)
        Rails.cache.write(key, value, options)
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
