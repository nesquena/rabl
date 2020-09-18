module Rabl
  class Digestor < ActionView::Digestor
    @@rabl_mutex = Mutex.new

    def self.digest(name, format, finder, options = {})
      cache_key = [name, format] + Array.wrap(options[:dependencies])
      @@rabl_mutex.synchronize do
        @@cache[cache_key.join('.')] ||= begin
          Digestor.new(name, format, finder, options).digest
        end
      end
    end
  end
end
