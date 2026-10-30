# frozen_string_literal: true

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

# We load the oj library if it is available (it becomes the default json_engine).
begin
  require 'oj'
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
    attr_accessor :camelize_keys

    DEFAULT_XML_OPTIONS = { :dasherize  => true, :skip_types => false }

    # The Oj options rabl renders with. rabl passes them to each Oj.dump (see #oj_dump_options),
    # so its output does not depend on Oj.default_options (#744). :nan => :word keeps
    # NaN/Infinity as they were when these were global (a global :compat writes them as words).
    OJ_OPTIONS = { :mode => :compat, :time_format => :ruby, :use_to_json => true, :nan => :word }.freeze

    # What Oj ships for the options rabl sets globally: Oj 3.2+ has mode :object, Oj 3.0/3.1
    # mode :custom. Oj 2.x ships time_format :unix_zone, so it counts as customized and is left alone.
    OJ_SHIPPED_OPTIONS = {
      :mode        => (defined?(::Oj::VERSION) && ::Oj::VERSION.start_with?('3.0.', '3.1.') ? :custom : :object),
      :time_format => :unix,
      :use_to_json => false
    }.freeze

    # When rabl is loaded before the app has chosen any of these, it sets them globally as it
    # always did (mode :compat, time_format :ruby, use_to_json true), so a json_engine wrapper
    # or app code calling Oj.dump(obj) without options keeps rabl's settings. If the app (or a
    # library loaded earlier) has already set one of them, its Oj.default_options are left
    # alone (#744). An app that sets exactly Oj's shipped values cannot be told apart from
    # one that set nothing, and gets rabl's settings as before.
    if defined?(::Oj) && ::Oj.default_options.values_at(*OJ_SHIPPED_OPTIONS.keys) == OJ_SHIPPED_OPTIONS.values
      ::Oj.default_options = OJ_OPTIONS.reject { |key, _| key == :nan }
    end

    # Oj modes an app can switch to after loading rabl that rabl's output follows, as it did
    # when rabl's settings were global (e.g. :rails, which escapes "<", ">" and "&")
    OJ_APP_MODES = [:compat, :rails, :custom].freeze

    # Oj.default_options once rabl was loaded, to tell which ones the app changed afterwards
    OJ_DEFAULTS_AT_LOAD = (::Oj.default_options.freeze if defined?(::Oj))

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
      @camelize_keys                                = false
    end

    # @return The JSON engine used to encode Rabl templates into JSON
    def json_engine
      @json_engine || (defined?(::Oj) ? ::Oj : ::JSON)
    end

    # The options rabl passes to Oj.dump (#744): OJ_OPTIONS, except where the app changed
    # Oj.default_options after rabl was loaded. Those changes win, as they did when rabl's
    # settings were global: a new :time_format or :use_to_json, and a new mode if it is one
    # of OJ_APP_MODES (then :nan follows that mode too). Another new mode (:strict, :null,
    # :object, ...) is ignored, since rabl's output would raise on or drop plain objects.
    # Options the app set before rabl was loaded are ignored too: rabl's output stays as it
    # was when rabl overwrote them.
    #
    # Only options that differ from the current global ones are returned, so with rabl's
    # globals in place the hash is empty and Oj.dump gets no options, as before: Oj before
    # 3.17.7 hands the options of Oj.dump to to_json, which json 3.x rejects (ArgumentError).
    # :nan is only needed with an explicit :mode (a global :compat already writes NaN as words).
    # ceiling: when the app configured Oj before loading rabl, options are still passed, so
    # Oj < 3.17.7 with json 3.x can raise on objects with to_json; upgrading Oj avoids it.
    # ceiling: Oj.default_options builds a new Hash on each render (a few microseconds);
    # caching it would miss changes the app makes later.
    def oj_dump_options
      current = ::Oj.default_options
      changed = lambda { |key| OJ_DEFAULTS_AT_LOAD && current[key] != OJ_DEFAULTS_AT_LOAD[key] }
      app_mode = changed.call(:mode) && OJ_APP_MODES.include?(current[:mode])

      options = OJ_OPTIONS.reject do |key, value|
        ([:mode, :nan].include?(key) ? app_mode : changed.call(key)) || current[key] == value
      end
      options.delete(:nan) unless options.key?(:mode)
      options
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
