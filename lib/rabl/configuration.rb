# We load the msgpack library if it is available.
begin
  require 'msgpack'
rescue LoadError
end

# We load the bson library if it is available.
begin
  require 'bson'
  rescue LoadError
end

# We load the plist library if it is available.
begin
  require 'plist'
rescue LoadError
end

# We load the csv library if it is available.
begin
  require 'csv'
rescue LoadError
end

# Load MultiJSON
require 'multi_json'

module Rabl
  # Rabl.host
  class Configuration
    attr_accessor :include_json_root
    attr_accessor :include_child_root
    attr_accessor :include_msgpack_root
    attr_accessor :include_plist_root
    attr_accessor :include_xml_root
    attr_accessor :include_bson_root
    attr_accessor :enable_json_callbacks
    attr_accessor :bson_check_keys
    attr_accessor :bson_move_id
    attr_writer   :msgpack_engine
    attr_writer   :bson_engine
    attr_writer   :plist_engine
    attr_writer   :csv_engine
    attr_writer   :xml_options
    attr_accessor   :csv_options
    attr_accessor :cache_sources
    attr_accessor :cache_all_output
    attr_accessor :escape_all_output
    attr_accessor :view_paths

    DEFAULT_XML_OPTIONS = { :dasherize  => true, :skip_types => false }

    def initialize
      @include_json_root     = true
      @include_child_root    = true
      @include_msgpack_root  = true
      @include_plist_root    = true
      @include_xml_root      = false
      @include_bson_root     = true
      @enable_json_callbacks = false
      @bson_check_keys       = false
      @bson_move_id          = false
      @json_engine           = nil
      @msgpack_engine        = nil
      @bson_engine           = nil
      @plist_engine          = nil
      @csv_engine            = nil
      @xml_options           = {}
      @csv_options           = {}
      @cache_sources         = false
      @cache_all_output      = false
      @escape_all_output     = false
      @view_paths            = []
    end

    # @param [Symbol, String, #encode] engine_name The name of a JSON engine,
    #   or class that responds to `encode`, to use to encode Rabl templates
    #   into JSON. For more details, see the MultiJson gem.
    def json_engine=(engine_name_or_class)
      @engine_name = engine_name_or_class
      # multi_json compatibility TODO
      MultiJson.respond_to?(:use) ? MultiJson.use(@engine_name) :
        MultiJson.engine = @engine_name
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

    ##
    # @return the Bson encoder/engine to use.
    def bson_engine
      @bson_engine || ::BSON
    end

    ##
    # @return the Plist encoder/engine to use.
    def plist_engine
      @plist_engine || ::Plist::Emit
    end

    ##
    # @return the CSV encoder/engine to use.
    def csv_engine
      @csv_engine || ::CSV
    end

    # Allows config options to be read like a hash
    #
    # @param [Symbol] option Key for a given attribute
    def [](option)
      __send__(option)
    end

    # Returns merged default and inputted xml options
    def default_xml_options
      @_default_xml_options ||= @xml_options.reverse_merge(DEFAULT_XML_OPTIONS)
    end

    private

    def get_json_engine
      if !defined?(@engine_name) && defined?(Rails)
        ActiveSupport::JSON
      else # use multi_json
        # multi_json compatibility TODO
        MultiJson.respond_to?(:adapter) ? MultiJson.adapter : MultiJson.engine
      end
    end
  end
end
