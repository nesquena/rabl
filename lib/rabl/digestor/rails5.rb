module Rabl
  class Digestor < ActionView::Digestor
    def self.digest(name:, finder:, **options)

      options.assert_valid_keys(:dependencies, :partial)

      cache_key = ([ name ].compact + Array.wrap(options[:dependencies])).join('.')

      # this is a correctly done double-checked locking idiom
      # (Concurrent::Map's lookups have volatile semantics)
      finder.digest_cache[cache_key] || @@digest_monitor.synchronize do
        finder.digest_cache.fetch(cache_key) do # re-check under lock
          begin
            # Prevent re-entry or else recursive templates will blow the stack.
            # There is no need to worry about other threads seeing the +false+ value,
            # as they will then have to wait for this thread to let go of the @@digest_monitor lock.

            pre_stored = finder.digest_cache.put_if_absent(cache_key, false).nil? # put_if_absent returns nil on insertion

            finder.digest_cache[cache_key] = stored_digest = Digestor.new(name, finder, options).digest
          ensure
            # something went wrong or ActionView::Resolver.caching? is false, make sure not to corrupt the @@cache
            finder.digest_cache.delete_pair(cache_key, false) if pre_stored && !stored_digest
          end
        end
      end
    end
  end
end
