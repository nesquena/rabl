module Rabl
  class CacheEngine

    def fetch(key, cache_options, &block)
      if defined?(Rails)
        Rails.cache.fetch(key, cache_options, &block)
      else
        yield
      end
    end

  end
end
