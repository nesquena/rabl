module Rabl
  class Digestor < ActionView::Digestor
    # Override the original digest function to ignore partial which
    # rabl doesn't use the Rails conventional _ symbol.
    def self.digest(name, format, finder, options = {})
      cache_key = [name, format] + Array.wrap(options[:dependencies])
      @@cache[cache_key.join('.')] ||= begin
        Digestor.new(name, format, finder, options).digest
      end
    end

    private
      def dependency_digest
        template_digests = dependencies.collect do |template_name|
          Digestor.digest(template_name, format, finder)
        end

        (template_digests + injected_dependencies).join("-")
      end
  end
end
