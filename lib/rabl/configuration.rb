module Rabl
  # Rabl.host
  class Configuration
    attr_accessor :include_json_root
    attr_accessor :include_xml_root
    attr_accessor :enable_json_callbacks

    def initialize
      @include_json_root     = true
      @include_xml_root      = false
      @enable_json_callbacks = false
    end

    # Allows config options to be read like a hash
    #
    # @param [Symbol] option Key for a given attribute
    def [](option)
      send(option)
    end
  end
end
