module Rabl
  class Digestor < ActionView::Digestor
    # Override the original digest function to ignore partial which
    # rabl doesn't use the Rails conventional _ symbol.
    if Rails.version.to_s >= '4.1'
      def self.digest(options = {})
        cache_key = [options[:name]] + Array.wrap(options[:dependencies])
        @@cache[cache_key.join('.')] ||= begin
          Digestor.new({ name: options[:name], finder: options[:finder] }.merge!(options)).digest
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
        template_digests = dependencies.collect do |template_name|
          if Rails.version.to_s >= '4.1'
            Digestor.digest(name: template_name, finder: finder)
          else
            Digestor.digest(template_name, format, finder)
          end
        end

        (template_digests + injected_dependencies).join("-")
      end
  end
end
