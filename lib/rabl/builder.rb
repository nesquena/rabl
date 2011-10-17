module Rabl
  class Builder
    include Rabl::Helpers

    # Constructs a new ejs hash based on given object and options
    # options = { :format => "json", :attributes, :root => true,
    #   :child_root => true, :code, :child, :glue, :extends }
    def initialize(data, options={}, &block)
      @options    = options
      @_scope     = options[:scope]
      @_data      = data
      @_object    = data_object(data)
      @_result    = {}
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true)
    def to_hash(options={})
      # Extends
      @options[:extends].each do |settings|
        extends(settings[:file], settings[:options], &settings[:block])
      end if @options.has_key?(:extends)
      # Attributes
      @options[:attributes].each_pair do |attribute, name|
        attribute(attribute, :as => name)
      end if @options.has_key?(:attributes)
      # Code
      @options[:code].each do |settings|
        code(settings[:name], settings[:options], &settings[:block])
      end if @options.has_key?(:code)
      # Children
      @options[:child].each do |settings|
        child(settings[:data], settings[:options], &settings[:block])
      end if @options.has_key?(:child)
      # Glues
      @options[:glue].each do |settings|
        glue(settings[:data], &settings[:block])
      end if @options.has_key?(:glue)
      # Return Hash
      @_root_name ||= data_name(@_data)
      (@options[:root] || options[:root]) && @_root_name ? { @_root_name => @_result } : @_result
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
          @_result[options[:as] || attribute] = @_object.send(attribute) if @_object && @_object.respond_to?(attribute)
        end
      end
    end
    alias_method :attributes, :attribute

    # Creates an arbitrary code node that is included in the json output
    # node(:foo) { "bar" }
    # code(:foo) { "bar" }
    # code(:foo, :if => lambda { |m| m.foo.present? }) { "bar" }
    def code(name, options={}, &block)
      return unless resolve_condition(options)
      result = block.call(@_object)
      if name.present?
        @_result[name] = result
      else
        @_result.merge!(result) if result
      end
    end
    alias_method :node, :code

    # Creates a child node that is included in json output
    # child(@user) { attribute :full_name }
    # child(@user => :person) { ... }
    # child(@users => :people) { ... }
    def child(data, options={}, &block)
      return false unless data.present? && resolve_condition(options)
      name, object = data_name(data), data_object(data)
      include_root = is_collection?(object) && @options[:child_root] # child @users
      engine_options = @options.slice(:child_root).merge(:root => include_root)
      object = { object => name } if data.respond_to?(:each_pair) && object # child :users => :people
      @_result[name] = self.object_to_hash(object, engine_options, &block) 
    end

    # Glues data from a child node to the json_output
    # glue(@user) { attribute :full_name => :user_full_name }
    def glue(data, &block)
      return false unless data.present?
      object = data_object(data)
      glued_attributes = self.object_to_hash(object, :root => false, &block)
      @_result.merge!(glued_attributes) if glued_attributes
    end

    # Extends an existing rabl template with additional attributes in the block
    # extends("users/show") { attribute :full_name }
    def extends(file, options={}, &block)
      options = @options.slice(:child_root).merge(options).merge(:object => @_object)
      result = self.partial(file, options, &block)
      @_result.merge!(result) if result
    end
  end
end
