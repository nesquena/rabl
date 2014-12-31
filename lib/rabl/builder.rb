module Rabl
  class Builder
    include Helpers
    include Partials

    SETTING_TYPES = {
      :attributes => :name,
      :node       => :name,
      :child      => :data,
      :glue       => :data,
      :extends    => :file
    } unless const_defined?(:SETTING_TYPES)

    # Constructs a new rabl hash based on given object and options
    # options = { :format => "json", :root => true, :child_root => true,
    #   :attributes, :node, :child, :glue, :extends }
    #
    def initialize(object, settings = {}, options = {}, &block)
      @_object = object

      @settings       = settings
      @options        = options
      @_context_scope = options[:scope]
      @_view_path     = options[:view_path]
    end

    def engines
      return @_engines if defined?(@_engines)

      @_engines = []

      # Append onto @_engines
      compile_settings(:extends)
      compile_settings(:child)
      compile_settings(:glue)

      @_engines
    end

    def replace_engine(engine, value)
      engines[engines.index(engine)] = value
    end

    def to_hash(object = nil, settings = {}, options = {})
      @_object = object           if object
      @options.merge!(options)    if options
      @settings.merge!(settings)  if settings

      cache_results do
        @_result = {}

        # Merges directly into @_result
        compile_settings(:attributes)

        merge_engines_into_result

        # Merges directly into @_result
        compile_settings(:node)

        replace_nil_values          if Rabl.configuration.replace_nil_values_with_empty_strings
        replace_empty_string_values if Rabl.configuration.replace_empty_string_values_with_nil_values
        remove_nil_values           if Rabl.configuration.exclude_nil_values

        result = @_result
        result = { @options[:root_name] => result } if @options[:root_name].present?
        result
      end
    end

    protected
      def replace_nil_values
        @_result = deep_replace_nil_values(@_result)
      end

      def deep_replace_nil_values(hash)
        hash.inject({}) do |new_hash, (k, v)|
          new_hash[k] = if v.is_a?(Hash)
            deep_replace_nil_values(v)
          else
            v.nil? ? '' : v
          end
          new_hash
        end
      end

      def replace_empty_string_values
        @_result = deep_replace_empty_string_values(@_result)
      end

      def deep_replace_empty_string_values(hash)
        hash.inject({}) do |new_hash, (k, v)|
          new_hash[k] = if v.is_a?(Hash)
            deep_replace_empty_string_values(v)
          else
            (!v.nil? && v != "") ? v : nil
          end

          new_hash
        end
      end

      def remove_nil_values
        @_result = @_result.inject({}) do |new_hash, (k, v)|
          new_hash[k] = v unless v.nil?
          new_hash
        end
      end

      def compile_settings(type)
        return unless @settings.has_key?(type)

        settings_type = SETTING_TYPES[type]
        @settings[type].each do |setting|
          send(type, setting[settings_type], setting[:options] || {}, &setting[:block])
        end
      end

      def merge_engines_into_result
        engines.each do |engine|
          case engine
          when Hash
            # engine was stored in the form { name => #<Engine> }
            engine.each do |key, value|
              engine[key] = value.render if value.is_a?(Engine)
            end
          when Engine
            engine = engine.render
          end

          @_result.merge!(engine) if engine.is_a?(Hash)
        end
      end

      # Indicates an attribute or method should be included in the json output
      # attribute :foo, :as => "bar"
      # attribute :foo, :as => "bar", :if => lambda { |m| m.foo }
      def attribute(name, options = {})
        return unless @_object && attribute_present?(name) && resolve_condition(options)

        attribute = data_object_attribute(name)
        name = (options[:as] || name).to_sym
        @_result[name] = attribute
      end
      alias_method :attributes, :attribute

      # Creates an arbitrary node that is included in the json output
      # node(:foo) { "bar" }
      # node(:foo, :if => lambda { |m| m.foo.present? }) { "bar" }
      def node(name, options = {}, &block)
        return unless resolve_condition(options)

        result = block.call(@_object)
        if name.present?
          @_result[name.to_sym] = result
        elsif result.is_a?(Hash) # merge hash into root hash
          @_result.merge!(result)
        end
      end
      alias_method :code, :node

      # Creates a child node that is included in json output
      # child(@user) { attribute :full_name }
      # child(@user => :person) { ... }
      # child(@users => :people) { ... }
      def child(data, options = {}, &block)
        return unless data.present? && resolve_condition(options)

        name   = is_name_value?(options[:root]) ? options[:root] : data_name(data)
        object = data_object(data)

        include_root = is_collection?(object) && options.fetch(:object_root, @options[:child_root]) # child @users
        engine_options = @options.slice(:child_root).merge(:root => include_root)
        engine_options.merge!(:object_root_name => options[:object_root]) if is_name_value?(options[:object_root])

        object = { object => name } if data.is_a?(Hash) && object # child :users => :people

        engines << { name.to_sym => object_to_engine(object, engine_options, &block) }
      end

      # Glues data from a child node to the json_output
      # glue(@user) { attribute :full_name => :user_full_name }
      def glue(data, options = {}, &block)
        return unless data.present? && resolve_condition(options)

        object = data_object(data)
        engine = object_to_engine(object, :root => false, &block)
        engines << engine if engine
      end

      # Extends an existing rabl template with additional attributes in the block
      # extends("users/show") { attribute :full_name }
      def extends(file, options = {}, &block)
        return unless resolve_condition(options)

        options = @options.slice(:child_root).merge(:object => @_object).merge(options)
        engines << partial_as_engine(file, options, &block)
      end

      # Evaluate conditions given a symbol/proc/lambda/variable to evaluate
      def call_condition_proc(condition, object)
        # This will evaluate lambda, proc & symbol and call it with 1 argument
        return condition.to_proc.call(object) if condition.respond_to?(:to_proc)
        # Else we send directly the object
        condition
      end

      # resolve_condition(:if => true) => true
      # resolve_condition(:if => 'Im truthy') => true
      # resolve_condition(:if => lambda { |m| false }) => false
      # resolve_condition(:unless => lambda { |m| false }) => true
      # resolve_condition(:unless => lambda { |m| false }, :if => proc { true}) => true
      def resolve_condition(options)
        result = true
        result &&= call_condition_proc(options[:if], @_object) if options.key?(:if)
        result &&= !call_condition_proc(options[:unless], @_object) if options.key?(:unless)
        result
      end

    private
      # Checks if an attribute is present. If not, check if the configuration specifies that this is an error
      # attribute_present?(created_at) => true
      def attribute_present?(name)
        if @_object.respond_to?(name)
          true
        elsif Rabl.configuration.raise_on_missing_attribute
          raise "Failed to render missing attribute #{name}"
        else
          false
        end
      end

      # Returns a guess at the format in this context_scope
      # request_format => "xml"
      def request_format
        format = @options[:format]
        format = "json" if !format || format == "hash"
        format
      end

      # Caches the results of the block based on object cache_key
      # cache_results { compile_hash(options) }
      def cache_results(&block)
        if template_cache_configured? && Rabl.configuration.cache_all_output && @_object.respond_to?(:cache_key)
          cache_key = [@_object, @options[:root_name], @options[:format]]

          fetch_result_from_cache(cache_key, &block)
        else # skip cache
          yield
        end
      end
  end
end
