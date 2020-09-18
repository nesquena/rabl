module Rabl
  class Digestor < ActionView::Digestor
    @@rabl_mutex = Mutex.new

    def self.digest(options = {})
      cache_key = [options[:name]] + Array.wrap(options[:dependencies])
      @@rabl_mutex.synchronize do
        @@cache[cache_key.join('.')] ||= begin
          Digestor.new({ :name => options[:name], :finder => options[:finder] }.merge!(options)).digest
        end
      end
    end
  end
end
