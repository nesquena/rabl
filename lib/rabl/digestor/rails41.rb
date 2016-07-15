module Rabl
  class Digestor < ActionView::Digestor
    def self.digest(options = {})
      cache_key = [options[:name]] + Array.wrap(options[:dependencies])
      @@cache[cache_key.join('.')] ||= begin
        Digestor.new({ :name => options[:name], :finder => options[:finder] }.merge!(options)).digest
      end
    end
  end
end
