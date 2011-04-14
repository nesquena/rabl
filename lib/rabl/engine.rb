module Rabl
  class Engine
    # Constructs a new ejs engine based on given vars, handler and declarations
    # Rabl::Engine.new("...source...", { :format => "xml", :root => true, :view_path => "/path/to/views" })
    def initialize(source, options={})
      @_source = source
      @_options = options.reverse_merge(:format => "json")
    end

    # Renders the representation based on source, object, scope and locals
    # Rabl::Engine.new("...source...", { :format => "xml" }).render(scope, { :foo => "bar", :object => @user })
    def render(scope, locals, &block)
      @_locals = locals
      @_scope = scope
      @_options = @_options.merge(:scope => @_scope, :locals => @_locals, :engine => self)
      self.copy_instance_variables_from(@_scope, [:@assigns, :@helpers])
      @_data = locals[:object] || self.default_object
      instance_eval(@_source) if @_source.present?
      instance_eval(&block) if block_given?
      self.send("to_" + @_options[:format].to_s)
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true)
    def to_hash(options={})
      object = data_object(@_data)
      if is_record?(object) # object @user
        Rabl::Builder.new(@_data, @_options).to_hash(options)
      elsif object.respond_to?(:each) # collection @users
        object.map { |object| Rabl::Builder.new(object, @_options).to_hash(options) }
      end
    end

    # Returns a json representation of the data object
    # to_json(:root => true)
    def to_json(options={})
      options = options.reverse_merge(:root => true)
      to_hash(options).to_json
    end

    # Returns a json representation of the data object
    # to_xml(:root => true)
    def to_xml(options={})
      options = options.reverse_merge(:root => false)
      to_hash(options).to_xml(:root => model_name(@_data))
    end

    # Sets the object to be used as the data source for this template
    # object(@user)
    # object @user => :person
    # object @users
    def object(data)
      @_data = data unless @_locals[:object]
    end

    # Sets the object as a collection casted to a simple array
    # collection @users
    def collection(data)
      self.object(data_object(data).to_a) if data
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
    # code(:foo, :if => lambda { ... }) { "bar" }
    def code(name, options={}, &block)
      @_options[:code] ||= {}
      @_options[:code][name] = { :options => options, :block => block }
    end
    alias_method :node, :code

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
      source = self.fetch_source(file)
      self.object_to_hash(options[:object], source, &block)
    end

    # Includes a helper module with a RABL template
    # helper ExampleHelper
    def helper(*klazzes)
      klazzes.each { |klazz| self.class.send(:include, klazz) }
    end
    alias_method :helpers, :helper

    # Returns a hash based representation of any data object given ejs template block
    # object_to_hash(@user) { attribute :full_name } => { ... }
    def object_to_hash(object, source=nil, &block)
      return object unless is_record?(object) || object.respond_to?(:each)
      self.class.new(source, :format => "hash", :root => false).render(@_scope, :object => object, &block)
    end

    # model_name(@user) => "user"
    # model_name([@user]) => "user"
    # model_name([]) => "array"
    def model_name(data)
      if data.respond_to?(:first) && data.first.respond_to?(:valid?)
        model_name(data.first).pluralize
      else # actual data object
        data.class.respond_to?(:model_name) ? data.class.model_name.element : data.class.to_s.downcase
      end
    end

    protected

    # Returns a guess at the default object for this template
    # default_object => @user
    def default_object
      @_scope.respond_to?(:controller) ?
        instance_variable_get("@#{@_scope.controller.controller_name}") :
        nil
    end

    # Returns true if item is a ORM record; false otherwise
    # is_record?(@user) => true
    def is_record?(obj)
      obj && data_object(obj).respond_to?(:valid?)
    end

    # Returns source for a given relative file
    # fetch_source("show") => "...contents..."
    def fetch_source(file)
      root_path = Rails.root if defined?(Rails)
      root_path = Padrino.root if defined?(Padrino)
      view_path = @_options[:view_path] || File.join(root_path, "app/views/")
      file_path = Dir[File.join(view_path, file + "*.rabl")].first
      File.read(file_path) if file_path
    end

    # data_object(data) => <AR Object>
    # data_object(@user => :person) => @user
    def data_object(data)
      data.respond_to?(:each_pair) ? data.keys.first : data
    end
  end
end