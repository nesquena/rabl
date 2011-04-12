module Rabl
  class Engine
    # Constructs a new ejs engine based on given vars, handler and declarations
    def initialize(vars, handler, source_string=nil, &block)
      @_vars = vars
      @_handler = handler
      @_options = { :handler => @_handler, :vars => @_vars, :engine => self }
      self.copy_instance_variables_from(@_handler, [:@assigns, :@helpers]);
      @_object = vars[:object] || self.default_object
      # raise @user.inspect + " - " + @_handler.instance_variable_get(:@options).inspect + " - " + @_handler.inspect
      instance_eval(source_string) if source_string.present?
      instance_eval(&block) if block_given?
    end

    # Sets the object to be used as the data source for this template
    # object(@user)
    def object(data)
      @_object = data
    end

    # Indicates an attribute or method should be included in the json output
    # attribute :foo, :as => "bar"
    # attribute :foo => :bar
    def attribute(*args)
      if args.first.is_a?(Hash)
        args.first.each_pair { |k,v| self.attribute(k, :as => v) }
      else # array of attributes
        options = args.extract_options!
        @_options[:attributes] ||= {}
        args.each { |name| @_options[:attributes][name] = options[:as] || name }
      end
    end
    alias_method :attributes, :attribute

    # Creates an arbitrary code node that is included in the json output
    # code(:foo) { "bar" }
    def code(name, &block)
      @_options[:code] ||= {}
      @_options[:code][name] = block
    end

    # Creates a child node that is included in json output
    # child(@user) { attribute :full_name }
    def child(data, options={}, &block)
      @_options[:child] ||= []
      @_options[:child].push({ :data => data, :options => options, :block => block })
    end

    # Glues data from a child node to the json_output
    # glue(@user) { attribute :full_name => :user_full_name }
    def glue(data, &block)
      @_options[:glue] ||= []
      @_options[:glue].push({ :data => data, :block => block })
    end

    # Extends an existing rabl template with additional attributes in the block
    # extends("users/show", :object => @user) { attribute :full_name }
    def extends(file, options={}, &block)
      @_options[:extends] ||= []
      @_options[:extends].push({ :file => file, :options => options, :block => block })
    end

    # Renders a partial hash based on another rabl template
    # partial("users/show", :object => @user)
    def partial(file, options={}, &block)
      source = File.read(Rails.root.join("app/views/" + file + ".json.rabl"))
      self.object_to_hash(options[:object], source, &block)
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true)
    def to_hash(options={})
      if @_object.is_a?(ActiveRecord::Base)
        Rabl::Builder.new(@_object, @_options).to_hash(options)
      elsif @_object.respond_to?(:each)
        @_object.map { |object| Rabl::Builder.new(object, @_options).to_hash(options) }
      end
    end

    # Returns a json representation of the data object
    # to_json(:root => true)
    def to_json(options={})
      options.reverse_merge!(:root => true)
      to_hash(options).to_json
    end

    # Returns a hash based representation of any data object given ejs template block
    # object_to_hash(@user) { attribute :full_name } => { ... }
    def object_to_hash(object, source=nil, &block)
      return object unless object.is_a?(ActiveRecord::Base) || object.first.is_a?(ActiveRecord::Base)
      self.class.new(@_vars.merge(:object => object), @_handler, source, &block).to_hash(:root => false)
    end

    protected

    # Returns a guess at the default object for this template
    def default_object
      @_handler.respond_to?(:controller) ?
        instance_variable_get("@#{@_handler.controller.controller_name}") :
        nil
    end
  end
end