# We load the msgpack library if it is available.
begin
  require 'msgpack'
rescue LoadError
end

module Rabl
  # Rabl.host
  class Configuration
    attr_accessor :include_json_root
    attr_accessor :include_msgpack_root
    attr_accessor :include_xml_root
    attr_accessor :enable_json_callbacks
    attr_writer   :json_engine
    attr_writer   :msgpack_engine
    attr_writer   :xml_options

    DEFAULT_XML_OPTIONS = { :dasherize  => true, :skip_types => false }

    def initialize
      @include_json_root     = true
      @include_msgpack_root  = true
      @include_xml_root      = false
      @enable_json_callbacks = false
      @json_engine           = nil
      @msgpack_engine        = nil
      @xml_options           = {}
    end

    # Returns the multi_json engine for use with RABL
    def json_engine
      @json_engine || MultiJson.engine
    end

    ##
    # @return the MessagePack encoder/engine to use.
    def msgpack_engine
      @msgpack_engine || ::MessagePack
    end

    # Allows config options to be read like a hash
    #
    # @param [Symbol] option Key for a given attribute
    def [](option)
      send(option)
    end

    # Returns merged default and inputted xml options
    def default_xml_options
      @_default_xml_options ||= @xml_options.reverse_merge(DEFAULT_XML_OPTIONS)
    end
  end
end
