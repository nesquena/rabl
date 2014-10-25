module Rabl
  class Builder
    include Rabl::Partials

    SETTING_TYPES = {
      :extends => :file,
      :node    => :name,
      :child   => :data,
      :glue    => :data
    } unless const_defined?(:SETTING_TYPES)

    # Constructs a new rabl hash based on given object and options
    # options = { :format => "json", :root => true, :child_root => true,
    #   :attributes, :node, :child, :glue, :extends }
    #
    def initialize(options = {}, &block)
      @options    = options
      @_scope     = options[:scope]
      @_view_path = options[:view_path]
    end

    # Given an object and options, returns the hash representation
    # build(@user, :format => "json", :attributes => { ... }, :root_name => "user")
    def build(object, options = {})
      @_object = object

      compile_engines

      to_hash(options) unless options[:keep_engines]
    end

    def engines
      @_engines ||= []
    end

    def replace_engine(engine, value)
      engines[engines.index(engine)] = value
    end

    def to_hash(options = {})
      cache_results { compile_hash(options) }
    end

    protected

    # Returns the builder with all engine-producing options evaluated.
    # (extends, node, children, glues)
    def compile_engines
      @_engines = []

      update_settings(:extends)
      update_settings(:child)
      update_settings(:glue)
    end

    # Returns a hash representation of the data object
    # compile_hash(:root_name => false)
    # compile_hash(:root_name => "user")
    def compile_hash(options = {})
      @_result = {}

      update_attributes

      # Turn engines into hashes
      @_engines.each do |engine|
        # engine was stored in the form { name => #<Rabl::Engine> }
        if engine.is_a?(Hash)
          engine.each do |key, value|
            if value.is_a?(Rabl::Engine)
              value = value.render

              if value
                engine[key] = value
              else
                engine.delete(key)
              end
            end
          end
        elsif engine.is_a?(Rabl::Engine)
          engine = engine.render
        end

        @_result.merge!(engine) if engine.is_a?(Hash)
      end

      @_engines = []

      update_settings(:node)

      replace_nil_values          if Rabl.configuration.replace_nil_values_with_empty_strings
      replace_empty_string_values if Rabl.configuration.replace_empty_string_values_with_nil_values
      remove_nil_values           if Rabl.configuration.exclude_nil_values

      # Return Results
      result = @_result
      result = { options[:root_name] => result } if options[:root_name].present?
      result
    end

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

    def update_settings(type)
      return unless @options.has_key?(type)

      settings_type = SETTING_TYPES[type]
      @options[type].each do |settings|
        send(type, settings[settings_type], settings[:options], &settings[:block])
      end
    end

    def update_attributes
      return unless @options.has_key?(:attributes)

      @options[:attributes].each do |attribute, settings|
        attribute(attribute, settings)
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

      @_engines << { name.to_sym => object_to_engine(object, engine_options, &block) }
    end

    # Glues data from a child node to the json_output
    # glue(@user) { attribute :full_name => :user_full_name }
    def glue(data, options = {}, &block)
      return unless data.present? && resolve_condition(options)

      object = data_object(data)
      @_engines << object_to_engine(object, :root => false, &block)
    end

    # Extends an existing rabl template with additional attributes in the block
    # extends("users/show") { attribute :full_name }
    def extends(file, options = {}, &block)
      return unless resolve_condition(options)

      options = @options.slice(:child_root).merge(:object => @_object).merge(options)
      @_engines << partial_as_engine(file, options, &block)
    end

    # Evaluate conditions given a symbol to evaluate
    def call_condition_proc(condition, object, &block)
      block = lambda { |v| v } unless block_given?

      if condition.respond_to?(:call)
        # condition is a block to pass to the block
        block.call(condition.call(object))
      elsif condition.is_a?(Symbol) && object.respond_to?(condition)
        # condition is a property of the object
        block.call(object.send(condition))
      else
        false
      end
    end

    # resolve_condition(:if => true) => true
    # resolve_condition(:if => lambda { |m| false }) => false
    # resolve_condition(:unless => lambda { |m| true }) => true
    def resolve_condition(options)
      return true if options[:if].nil? && options[:unless].nil?

      result = nil
      if options.has_key?(:if)
        result = options[:if] == true || call_condition_proc(options[:if], @_object)
      end

      if options.has_key?(:unless)
        inverse_proc = lambda { |r| !r }
        result = options[:unless] == false || call_condition_proc(options[:unless], @_object, &inverse_proc)
      end

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

      # Returns a guess at the format in this scope
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
