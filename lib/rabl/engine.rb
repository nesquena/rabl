module Rabl
  class Engine
    include Rabl::Helpers

    # Constructs a new ejs engine based on given vars, handler and declarations
    # Rabl::Engine.new("...source...", { :format => "xml", :root => true, :view_path => "/path/to/views" })
    def initialize(source, options={})
      @_source = source
      @_options = options
    end

    # Renders the representation based on source, object, scope and locals
    # Rabl::Engine.new("...source...", { :format => "xml" }).render(scope, { :foo => "bar", :object => @user })
    def render(scope, locals, &block)
      @_locals, @_scope = locals, scope
      self.copy_instance_variables_from(@_scope, [:@assigns, :@helpers])
      @_options[:scope] = @_scope
      @_options[:format] ||= self.request_format
      @_data = locals[:object] || self.default_object
      if @_options[:source_location]
        instance_eval(@_source, @_options[:source_location]) if @_source.present?
      else
        instance_eval(@_source) if @_source.present?
      end
      instance_eval(&block) if block_given?
      self.send("to_" + @_options[:format].to_s)
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true, :child_root => true)
    def to_hash(options={})
      options = options.reverse_merge(@_options)
      data = data_object(@_data)
      if is_object?(data) || !data # object @user
        Rabl::Builder.new(@_data, options).to_hash(options)
      elsif is_collection?(data) # collection @users
        object_name = @_child_root || data_name(@_data).to_s.singularize # @users => :users
        data.map { |object| Rabl::Builder.new({ object => object_name }, options).to_hash(options) }
      end
    end

    # Returns a json representation of the data object
    # to_json(:root => true)
    def to_json(options={})
      include_root = Rabl.configuration.include_json_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      result = defined?(@_collection_name) ? { @_collection_name => to_hash(options) } : to_hash(options)
      format_json(result)
    end

    # Returns a msgpack representation of the data object
    # to_msgpack(:root => true)
    def to_msgpack(options={})
      include_root = Rabl.configuration.include_msgpack_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      result = defined?(@_collection_name) ? { @_collection_name => to_hash(options) } : to_hash(options)
      Rabl.configuration.msgpack_engine.pack result
    end

    # Returns an xml representation of the data object
    # to_xml(:root => true)
    def to_xml(options={})
      include_root = Rabl.configuration.include_xml_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      xml_options = Rabl.configuration.default_xml_options.merge(:root => data_name(@_data))
      to_hash(options).to_xml(xml_options)
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
    # collection @users => :people
    # collection @users, :child_root => :person # Rename each child to person, enclose in single array
    def collection(data, options = {})
      @_collection_name = data.values.first if data.respond_to?(:each_pair)
      @_child_root = options[:child_root] if options[:child_root]
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
    def code(name = nil, options={}, &block)
      @_options[:code] ||= []
      @_options[:code] << { :name => name, :options => options, :block => block }
    end
    alias_method :node, :code

    # Creates a child node that is included in json output
    # child(@user) { attribute :full_name }
    def child(data, options={}, &block)
      # Renders a child object/collection using the partial template provided
      # via the partial option. This cleans up the semantics and allows flexible re-use
      # of partial in associations
      if options[:partial]
        child(data, option.reverse_merge(:partial => nil)) { extends options[:partial] }
      else
        @_options[:child] ||= []
        @_options[:child].push({ :data => data, :options => options, :block => block })
      end
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

    # Includes a helper module with a RABL template
    # helper ExampleHelper
    def helper(*klazzes)
      klazzes.each { |klazz| self.class.send(:include, klazz) }
    end
    alias_method :helpers, :helper

    protected

    # Returns a guess at the default object for this template
    # default_object => @user
    def default_object
      if @_scope.respond_to?(:controller)
        full_name = @_scope.controller.controller_name
        instance_variable_get("@#{ full_name.split("::").last }")
      end
    end

    # Returns a guess at the format in this scope
    # request_format => "xml"
    def request_format
      format = self.request_params.has_key?(:format) ? @_scope.params[:format] : nil
      if request = @_scope.respond_to?(:request) && @_scope.request
        format ||= request.format.to_sym.to_s if request.respond_to?(:format)
      end
      format && self.respond_to?("to_#{format}") ? format : "json"
    end

    # Returns the request parameters if available in the scope
    # request_params => { :foo => "bar" }
    def request_params
      @_scope.respond_to?(:params) ? @_scope.params : {}
    end

    # Returns data as json embraced with callback when detected
    # format_json({ :foo => "bar" }) => "test({ foo : 'bar' })"
    # format_json("{ foo : "bar" }") => "test({ foo : 'bar' })"
    def format_json(json_output)
      json_output = Rabl.configuration.json_engine.encode(json_output) unless json_output.is_a?(String)
      use_callback = Rabl.configuration.enable_json_callbacks && request_params[:callback].present?
      use_callback ? "#{request_params[:callback]}(#{json_output})" : json_output
    end

    # Augments respond to supporting scope methods
    def respond_to?(name, include_private=false)
      @_scope.respond_to?(name, include_private) ? true : super
    end

    # Supports calling helpers defined for the template scope using method_missing hook
    def method_missing(name, *args, &block)
      @_scope.respond_to?(name) ? @_scope.send(name, *args, &block) : super
    end

    def copy_instance_variables_from(object, exclude = []) #:nodoc:
      vars = object.instance_variables.map(&:to_s) - exclude.map(&:to_s)
      vars.each { |name| instance_variable_set(name, object.instance_variable_get(name)) }
    end
  end
end
