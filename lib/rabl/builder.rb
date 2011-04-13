module Rabl
  class Builder
    # Constructs a new ejs hash based on given object and options
    def initialize(object, options, &block)
      @_object = object
      @_result = {}
      @options = options
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true)
    def to_hash(options={})
      # Attributes
      @options[:attributes].each_pair do |attribute, name|
        attribute(attribute, :as => name)
      end if @options.has_key?(:attributes)
      # Code
      @options[:code].each_pair do |name, block|
        code(name, &block)
      end if @options.has_key?(:code)
      # Children
      @options[:child].each do |settings|
        child(settings[:data], settings[:options], &settings[:block])
      end if @options.has_key?(:child)
      # Glues
      @options[:glue].each do |settings|
        glue(settings[:data], &settings[:block])
      end if @options.has_key?(:glue)
      # Extends
      @options[:extends].each do |settings|
        extends(settings[:file], settings[:options], &settings[:block])
      end if @options.has_key?(:extends)

      @_root_name ||= @_object.class.model_name.element
      (@options[:root] || options[:root]) ? { @_root_name => @_result } : @_result
    end

    # Indicates an attribute or method should be included in the json output
    # attribute :foo, :as => "bar"
    # attribute :foo => :bar
    def attribute(*args)
      if args.first.is_a?(Hash)
        args.first.each_pair { |k,v| self.attribute(k, :as => v) }
      else # array of attributes
        options = args.extract_options!
        args.each do |attribute|
          @_result[options[:as] || attribute] = @_object.try(attribute) if @_object.respond_to?(attribute)
        end
      end
    end
    alias_method :attributes, :attribute

    # Creates an arbitrary code node that is included in the json output
    # code(:foo) { "bar" }
    # code(:foo, :if => lambda { |m| m.foo.present? }) { "bar" }
    def code(name, options={}, &block)
      append_node = options[:if].nil? || (options[:if].respond_to?(:call) && options[:if].call(@_object))
      @_result[name] = block.call(@_object) if append_node
    end

    # Creates a child node that is included in json output
    # child(@user) { attribute :full_name }
    # child(@user => :person) { ... }
    def child(data, options={}, &block)
      return false unless data.present?
      name, object = data_name(data), data_object(data)
      @_result[name] = self.object_to_hash(object, &block)
    end

    # Glues data from a child node to the json_output
    # glue(@user) { attribute :full_name => :user_full_name }
    def glue(data, &block)
      return false unless data.present?
      object = data_object(data)
      glued_attributes = self.object_to_hash(object, &block)
      @_result.merge!(glued_attributes)
    end

    # Extends an existing rabl template with additional attributes in the block
    # extends("users/show") { attribute :full_name }
    def extends(file, options={}, &block)
      options = options.merge(:object => @_object)
      result = @options[:engine].partial(file, options, &block)
      @_result.merge!(result)
    end

    protected

    # Returns a hash based representation of any data object given ejs template block
    # object_to_hash(@user) { attribute :full_name } => { ... }
    def object_to_hash(object, source=nil, &block)
      @options[:engine].object_to_hash(object, source, &block)
    end

    # data_object(data) => <AR Object>
    # data_object(@user => :person) => @user
    # data_object(:user => :person) => @_object.send(:user)
    def data_object(data)
      data = (data.is_a?(Hash) && data.keys.one?) ? data.keys.first : data
      data.is_a?(Symbol)      ? @_object.send(data) : data
    end

    # data_name(data) => "user"
    # data_name(@user => :person) => :person
    # data_name(@users) => :user
    def data_name(data)
      return data.values.first if data.is_a?(Hash)
      return data.first.class.model_name.element.pluralize if data.respond_to?(:first) && data.first.respond_to?(:valid?)
      data.class.model_name.element
    end
  end
end