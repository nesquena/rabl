module Rabl
  class ObjectNode
    include Rabl::Partials

    OBJECT_DELEGATES = [:attribute, :attributes, :node, :code, :child, :glue, :extends, :helper, :helpers, :partial]

    # Constructs an object node with associated rules
    # Rabl::ObjectNode.new(@posts) { attributes :foo, :bar }
    def initialize(data, options={}, &block)
      @_data = data
      @_options = options
      @_scope = options[:scope]
      self.copy_instance_variables_from(@_scope, [:@assigns, :@helpers])
      reset_options!
      instance_eval(&block) if block_given?
    end

    def to_hash(options={})
      options = @_options.merge(options)
      data = data_object(@_data)
      builder = Rabl::Builder.new(options)
      options[:root_name] ||= determine_object_root(@_data, options[:root])

      if is_object?(data) || !data # object @user
        builder.build(data, options)
      elsif is_collection?(data) # collection @users
        data.map { |object| builder.build(object, options) }
      end
    end

    # Indicates an attribute or method should be included in the json output
    # attribute :foo, :as => "bar"
    # attribute :foo => :bar
    def attribute(*args)
      if args.first.is_a?(Hash) # :foo => :bar, :bar => :baz
        args.first.each_pair { |k,v| self.attribute(k, :as => v) }
      else # array of attributes i.e :foo, :bar, :baz
        options = args.extract_options!
        args.each { |name| @_options[:attributes][name] = options[:as] || name }
      end
    end
    alias_method :attributes, :attribute

    # Creates an arbitrary node that is included in the json output.
    # node(:foo) { "bar" }
    # node(:foo, :if => lambda { ... }) { "bar" }
    def node(name = nil, options={}, &block)
      @_options[:node].push({ :name => name, :options => options, :block => block })
    end
    alias_method :code, :node

    # Creates a child node that is included in json output
    # child(@user) { attribute :full_name }
    def child(data, options={}, &block)
      @_options[:child].push({ :data => data, :options => options, :block => block })
    end

    # Glues data from a child node to the json_output
    # glue(@user) { attribute :full_name => :user_full_name }
    def glue(data, &block)
      @_options[:glue].push({ :data => data, :block => block })
    end

    # Extends an existing rabl template with additional attributes in the block
    # extends("users/show", :object => @user) { attribute :full_name }
    def extends(file, options={}, &block)
      @_options[:extends].push({ :file => file, :options => options, :block => block })
    end

    # Includes a helper module with a RABL template
    # helper ExampleHelper
    def helper(*klazzes)
      klazzes.each { |klazz| self.class.send(:include, klazz) }
    end
    alias_method :helpers, :helper

    # Return data object
    def data; @_data; end
    def options; @_options; end

    protected

    def copy_instance_variables_from(object, exclude = []) #:nodoc:
      vars = object.instance_variables.map(&:to_s) - exclude.map(&:to_s)
      vars.each { |name| instance_variable_set(name, object.instance_variable_get(name)) }
    end

    private

    # Resets the options parsed from a rabl template.
    def reset_options!
      @_options[:attributes] = {}
      @_options[:node] = []
      @_options[:child] = []
      @_options[:glue] = []
      @_options[:extends] = []
    end

    # Augments respond to supporting scope methods
    def respond_to?(name, include_private=false)
      context_scope.respond_to?(name, include_private) ? true : super
    end

    # Supports calling helpers defined for the template scope using method_missing hook
    def method_missing(name, *args, &block)
      context_scope.respond_to?(name) ? context_scope.send(name, *args, &block) : super
    end

  end
end