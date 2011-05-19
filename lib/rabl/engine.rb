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
      @_options[:format] ||= default_format
      @_data = locals[:object] || self.default_object
      instance_eval(@_source) if @_source.present?
      instance_eval(&block) if block_given?
      self.send("to_" + @_options[:format].to_s)
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true, :child_root => true)
    def to_hash(options={})
      options = options.reverse_merge(@_options)
      data = data_object(@_data)
      if is_record?(data) || !data # object @user
        Rabl::Builder.new(@_data, options).to_hash(options)
      elsif data.respond_to?(:each) # collection @users
        object_name = data_name(@_data).to_s.singularize # @users => :users
        data.map { |object| Rabl::Builder.new({ object => object_name }, options).to_hash(options) }
      end
    end

    # Returns a json representation of the data object
    # to_json(:root => true)
    def to_json(options={})
      include_root = Rabl.configuration.include_json_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      result = @_collection_name ? { @_collection_name => to_hash(options) } : to_hash(options)
      format_json(result.to_json)
    end

    # Returns an xml representation of the data object
    # to_xml(:root => true)
    def to_xml(options={})
      include_root = Rabl.configuration.include_xml_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      to_hash(options).to_xml(:root => data_name(@_data))
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
    def collection(data)
      @_collection_name = data.values.first if data.respond_to?(:each_pair)
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
      @_scope.respond_to?(:controller) ?
        instance_variable_get("@#{@_scope.controller.controller_name}") :
        nil
    end

    # Returns a guess at the format in this scope
    # default_format => "xml"
    def default_format
      # make use of the request format to check for the default format
      # to support format specified in the Accepts Header. The second condition is
      # just a paranoid fallback, just incase.
      format = @_scope.respond_to?(:request) ?
         @_scope.request.format.to_sym.to_s :
         (self.request_params.has_key?(:format) ? @_scope.params[:format] : nil)
      format || "json"
    end

    # Returns the request parameters if available in the scope
    # request_params => { :foo => "bar" }
    def request_params
      @_scope.respond_to?(:params) ? @_scope.params : {}
    end

    # Returns json embraced with callback if appropriate or plain if not
    # detect_jsonp({ foo : "bar" }) => "test({ foo : 'bar' })"
    def format_json(json_output)
      use_callback = Rabl.configuration.enable_json_callbacks && request_params[:callback].present?
      use_callback ? "#{request_params[:callback]}(#{json_output})" : json_output
    end

    # Supports calling helpers defined for the template scope using method_missing hook
    def method_missing(name, *args, &block)
      @_scope.respond_to?(name) ? @_scope.send(name, *args, &block) : super
    end
  end
end