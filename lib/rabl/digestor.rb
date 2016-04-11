module Rabl
  class Digestor < ActionView::Digestor
    # Override the original digest function to ignore partial which
    # rabl doesn't use the Rails conventional _ symbol.
    if Gem::Version.new(Rails.version) >= Gem::Version.new('5.0.0.beta1')
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
    elsif Gem::Version.new(Rails.version) >= Gem::Version.new('4.1')
      def self.digest(options = {})
        cache_key = [options[:name]] + Array.wrap(options[:dependencies])
        @@cache[cache_key.join('.')] ||= begin
          Digestor.new({ :name => options[:name], :finder => options[:finder] }.merge!(options)).digest
        end
      end
    else
      def self.digest(name, format, finder, options = {})
        cache_key = [name, format] + Array.wrap(options[:dependencies])
        @@cache[cache_key.join('.')] ||= begin
          Digestor.new(name, format, finder, options).digest
        end
      end
    end

    private
      def dependency_digest
        template_digests = (dependencies - [template.virtual_path]).collect do |template_name|
          if Gem::Version.new(Rails.version) >= Gem::Version.new('4.1')
            Digestor.digest(:name => template_name, :finder => finder)
          else
            Digestor.digest(template_name, format, finder)
          end
        end

        (template_digests + injected_dependencies).join("-")
      end
  end
end
