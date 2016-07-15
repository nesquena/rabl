module Rabl
  class Digestor < ActionView::Digestor
    def self.digest(name, format, finder, options = {})
      cache_key = [name, format] + Array.wrap(options[:dependencies])
      @@cache[cache_key.join('.')] ||= begin
        Digestor.new(name, format, finder, options).digest
      end
    end
  end
end
