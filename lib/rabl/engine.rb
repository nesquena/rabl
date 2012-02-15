module Rabl
  class Engine
    include Rabl::Partials

    # Constructs a new ejs engine based on given vars, handler and declarations
    # Rabl::Engine.new("...source...", { :format => "xml", :root => true, :view_path => "/path/to/views" })
    def initialize(source, options={})
      @_source = source
      @_options = options
    end

    # Renders the representation based on source, object, scope and locals
    # Rabl::Engine.new("...source...", { :format => "xml" }).render(scope, { :foo => "bar", :object => @user })
    def render(scope, locals, &block)
      reset_options!
      @_locals, @_scope = locals, scope
      self.copy_instance_variables_from(@_scope, [:@assigns, :@helpers])
      @_options[:scope] = @_scope
      @_options[:format] ||= self.request_format
      @_data = locals[:object] || self.default_object
      if @_options[:source_location]
        instance_eval(@_source, @_options[:source_location]) if @_source.present?
      else # without source location
        instance_eval(@_source) if @_source.present?
      end
      instance_eval(&block) if block_given?
      self.send("to_" + @_options[:format].to_s)
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true, :child_root => true)
    def to_hash(options={})
      options = @_options.merge(options)
      data, root_name = data_object(@_data), data_name(@_data)
      builder = Rabl::Builder.new(options)
      if is_object?(data) || !data # object @user
        options[:root_name] = root_name if options[:root]
        builder.build(data, options)
      elsif is_collection?(data) # collection @users
        options[:root_name] = object_root_name if object_root_name
        options[:root_name] ||= root_name.to_s.singularize if options[:root]
        data.map { |object| builder.build(object, options) }
      end
    end

    # Returns a json representation of the data object
    # to_json(:root => true)
    def to_json(options={})
      include_root = Rabl.configuration.include_json_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      result = collection_root_name ? { collection_root_name => to_hash(options) } : to_hash(options)
      format_json(result)
    end

    # Returns a msgpack representation of the data object
    # to_msgpack(:root => true)
    def to_msgpack(options={})
      include_root = Rabl.configuration.include_msgpack_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      result = collection_root_name ? { collection_root_name => to_hash(options) } : to_hash(options)
      Rabl.configuration.msgpack_engine.pack result
    end
    alias_method :to_mpac, :to_msgpack

    # Returns a plist representation of the data object
    # to_plist(:root => true)
    def to_plist(options={})
      include_root = Rabl.configuration.include_plist_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      result = defined?(@_collection_name) ? { @_collection_name => to_hash(options) } : to_hash(options)
      Rabl.configuration.plist_engine.dump(result)
    end

    # Returns an xml representation of the data object
    # to_xml(:root => true)
    def to_xml(options={})
      include_root = Rabl.configuration.include_xml_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      xml_options = Rabl.configuration.default_xml_options.merge(:root => data_name(@_data))
      to_hash(options).to_xml(xml_options)
    end

    # Returns a bson representation of the data object
    # to_bson(:root => true)
    def to_bson(options={})
      include_root = Rabl.configuration.include_bson_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      result = if collection_root_name
                 { collection_root_name => to_hash(options) }
               elsif is_collection?(@_data) && @_data.is_a?(Array)
                 { data_name(@_data) => to_hash(options) }
               else
                 to_hash(options)
               end
      Rabl.configuration.bson_engine.serialize(result).to_s
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
    # collection @users, :root => :person
    # collection @users, :object_root => :person
    def collection(data, options={})
      @_collection_name = options[:root] if options[:root]
      @_collection_name ||= data.values.first if data.respond_to?(:each_pair)
      @_object_root_name = options[:object_root] if options[:object_root]
      self.object(data_object(data).to_a) if data
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

    protected

    # Returns a guess at the default object for this template
    # default_object => @user
    def default_object
      if context_scope.respond_to?(:controller)
        full_name = context_scope.controller.controller_name
        instance_variable_get("@#{ full_name.split("::").last }")
      end
    end

    # Returns a guess at the format in this scope
    # request_format => "xml"
    def request_format
      format = self.request_params.has_key?(:format) ? context_scope.params[:format] : nil
      if request = context_scope.respond_to?(:request) && context_scope.request
        format ||= request.format.to_sym.to_s if request.respond_to?(:format)
      end
      format && self.respond_to?("to_#{format}") ? format : "json"
    end

    # Returns the request parameters if available in the scope
    # request_params => { :foo => "bar" }
    def request_params
      context_scope.respond_to?(:params) ? context_scope.params : {}
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
      context_scope.respond_to?(name, include_private) ? true : super
    end

    # Supports calling helpers defined for the template scope using method_missing hook
    def method_missing(name, *args, &block)
      context_scope.respond_to?(name) ? context_scope.send(name, *args, &block) : super
    end

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
      @_options[:root_name]  = nil
    end
  end
end
