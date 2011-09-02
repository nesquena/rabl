# We load the msgpack library if it is available.
begin
  require 'msgpack'
rescue LoadError
end

# Load MultiJSON
require 'multi_json'

module Rabl
  # Rabl.host
  class Configuration
    attr_accessor :include_json_root
    attr_accessor :include_msgpack_root
    attr_accessor :include_xml_root
    attr_accessor :enable_json_callbacks
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

    # @param [Symbol, String, #encode] engine_name The name of a JSON engine,
    #   or class that responds to `encode`, to use to encode Rabl templates
    #   into JSON. For more details, see the MultiJson gem.
    def json_engine=(engine_name_or_class)
      MultiJson.engine = @engine_name = engine_name_or_class
    end

    # @return The JSON engine used to encode Rabl templates into JSON
    def json_engine
      get_json_engine
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

    private

    def get_json_engine
      if !defined?(@engine_name) && defined?(Rails)
        ActiveSupport::JSON
      else
        MultiJson.engine
      end
    end
  end
end
