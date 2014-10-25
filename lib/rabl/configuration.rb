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

# Set default options for Oj json parser (if exists)
begin
  require 'oj'
  Oj.default_options =  { :mode => :compat, :time_format => :ruby, :use_to_json => true }
rescue LoadError
end

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
    attr_writer   :json_engine
    attr_writer   :msgpack_engine
    attr_writer   :bson_engine
    attr_writer   :plist_engine
    attr_writer   :xml_options
    attr_accessor :cache_sources
    attr_accessor :cache_all_output
    attr_accessor :escape_all_output
    attr_accessor :view_paths
    attr_accessor :cache_engine
    attr_accessor :raise_on_missing_attribute
    attr_accessor :perform_caching
    attr_accessor :use_read_multi
    attr_accessor :replace_nil_values_with_empty_strings
    attr_accessor :replace_empty_string_values_with_nil_values
    attr_accessor :exclude_nil_values
    attr_accessor :exclude_empty_values_in_collections

    DEFAULT_XML_OPTIONS = { :dasherize  => true, :skip_types => false }

    def initialize
      @include_json_root                            = true
      @include_child_root                           = true
      @include_msgpack_root                         = true
      @include_plist_root                           = true
      @include_xml_root                             = false
      @include_bson_root                            = true
      @enable_json_callbacks                        = false
      @bson_check_keys                              = false
      @bson_move_id                                 = false
      @json_engine                                  = nil
      @msgpack_engine                               = nil
      @bson_engine                                  = nil
      @plist_engine                                 = nil
      @xml_options                                  = {}
      @cache_sources                                = false
      @cache_all_output                             = false
      @escape_all_output                            = false
      @view_paths                                   = []
      @cache_engine                                 = Rabl::CacheEngine.new
      @perform_caching                              = false
      @use_read_multi                               = true
      @replace_nil_values_with_empty_strings        = false
      @replace_empty_string_values_with_nil_values  = false
      @exclude_nil_values                           = false
      @exclude_empty_values_in_collections          = false
    end

    # @return The JSON engine used to encode Rabl templates into JSON
    def json_engine
      @json_engine || (defined?(::Oj) ? ::Oj : ::JSON)
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
  end
end
