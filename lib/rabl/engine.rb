module Rabl
  class Engine
    include Rabl::Partials

    # List of supported rendering formats
    FORMATS = [:json, :xml, :plist, :bson, :msgpack]

    # Constructs a new ejs engine based on given vars, handler and declarations
    # Rabl::Engine.new("...source...", { :format => "xml", :root => true, :view_path => "/path/to/views" })
    def initialize(source, options={})
      @_source = source
      @_options = options
      @_view_path = options[:view_path]
    end

    def source=(string)
      @_source = string
    end

    # Renders the representation based on source, object, scope and locals
    # Rabl::Engine.new("...source...", { :format => "xml" }).render(scope, { :foo => "bar", :object => @user })
    def render(scope, locals, &block)
      reset_options!
      @_locals, @_scope = locals, scope
      self.copy_instance_variables_from(@_scope, [:@assigns, :@helpers])
      locals.merge!(locals.delete(:locals) || {})
      locals.each { |k,v| instance_variable_set(:"@#{k}", v) }
      @_options[:scope] = @_scope
      @_options[:format] ||= self.request_format
      if @_options[:source_location]
        instance_eval(@_source, @_options[:source_location]) if @_source.present?
      else # without source location
        instance_eval(@_source) if @_source.present?
      end
      instance_exec(root_object, &block) if block_given?
      cache_results { self.send("to_" + @_options[:format].to_s, @_options) }
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true, :child_root => true)
    def to_hash(options={})
      options = options.merge(@_options)
      data = root_object
      builder = Rabl::Builder.new(options)
      options[:root_name] = determine_object_root(data, root_name, options[:root])

      if is_object?(data) || !data # object @user
        builder.build(data, options)
      elsif is_collection?(data) # collection @users
        result = data.map { |object| builder.build(object, options) }
        result = result.map(&:presence).compact if Rabl.configuration.exclude_empty_values_in_collections
        result
      end
    end

    # Returns a json representation of the data object
    # to_json(:root => true)
    def to_json(options={})
      include_root = Rabl.configuration.include_json_root
      include_child_root = Rabl.configuration.include_child_root
      options = options.reverse_merge(:root => include_root, :child_root => include_child_root)
      result = collection_root_name ? { collection_root_name => to_hash(options) } : to_hash(options)
      format_json(result)
    end

    # Returns a msgpack representation of the data object
    # to_msgpack(:root => true)
    def to_msgpack(options={})
      include_root = Rabl.configuration.include_msgpack_root
      include_child_root = Rabl.configuration.include_child_root
      options = options.reverse_merge(:root => include_root, :child_root => include_child_root)
      result = collection_root_name ? { collection_root_name => to_hash(options) } : to_hash(options)
      Rabl.configuration.msgpack_engine.pack result
    end
    alias_method :to_mpac, :to_msgpack

    # Returns a plist representation of the data object
    # to_plist(:root => true)
    def to_plist(options={})
      include_root = Rabl.configuration.include_plist_root
      include_child_root = Rabl.configuration.include_child_root
      options = options.reverse_merge(:root => include_root, :child_root => include_child_root)
      result = defined?(@_collection_name) ? { @_collection_name => to_hash(options) } : to_hash(options)
      Rabl.configuration.plist_engine.dump(result)
    end

    # Returns an xml representation of the data object
    # to_xml(:root => true)
    def to_xml(options={})
      include_root = Rabl.configuration.include_xml_root
      include_child_root = include_root && Rabl.configuration.include_child_root
      options = options.reverse_merge(:root => include_root, :child_root => include_child_root)
      xml_options = Rabl.configuration.default_xml_options.merge(:root => collection_root_name || root_name)
      result = to_hash(options)
      result.to_xml(xml_options)
    end

    # Returns a bson representation of the data object
    # to_bson(:root => true)
    def to_bson(options={})
      include_root = Rabl.configuration.include_bson_root
      include_child_root = Rabl.configuration.include_child_root
      options = options.reverse_merge(:root => include_root, :child_root => include_child_root)
      result = if collection_root_name
                 { collection_root_name => to_hash(options) }
               elsif is_collection?(root_object) && root_object.is_a?(Array)
                 { root_name => to_hash(options) }
               else
                 to_hash(options)
               end
      Rabl.configuration.bson_engine.serialize(result).to_s
    end

    # Sets the object to be used as the data source for this template
    # object(@user)
    # object @user => :person
    # object @users
    def object(template_data)
      current_data  = (@_locals[:object].nil? || template_data == false) ? template_data : @_locals[:object]
      @_data_object = data_object(current_data)
      @_data_name   = data_name(template_data.is_a?(Hash) && !current_data.is_a?(Hash) ? template_data : current_data)
    end

    # Returns the current object that is the topic of this template
    # Can be the collection or the object depending on topic assigned
    # root_object => @user
    def root_object
      return @_data_object if defined?(@_data_object)

      data = @_locals[:object].nil? ? self.default_object : @_locals[:object]
      @_data_object = data_object(data)
    end

    def root_name
      return @_data_name if defined?(@_data_name)

      @_data_name = @_options[:object_root_name] || begin
        data = @_locals[:object].nil? ? root_object : @_locals[:object]
        data_name(data)
      end
    end

    # Sets the object as a collection casted to a simple array
    # collection @users
    # collection @users => :people
    # collection @users, :root => :person
    # collection @users, :object_root => :person
    def collection(data, options={})
      @_collection_name = options[:root] if options[:root]
      @_collection_name ||= data.values.first if data.respond_to?(:each_pair)
      @_object_root_name = options[:object_root] if options.has_key?(:object_root)
      self.object(Array(data_object(data)))
    end

    # Sets the cache key to be used by ActiveSupport::Cache.expand_cache_key
    # cache @user            # calls @user.cache_key
    # cache ['rabl', @user]  # calls @user.cache_key and prefixes with rabl/
    # cache 'user'           # explicit key of 'user'
    # cache                  # uses the current item within a collection
    # cache 'user', expires_in: 1.hour
    # options is passed through to the cache store
    def cache(key = nil, options = nil)
      key ||= root_object # if called but missing, use object
      @_cache = [key, options]
    end

    # Indicates an attribute or method should be included in the json output
    # attribute :foo, :as => "bar"
    # attribute :foo => :bar, :bar => :baz
    # attribute :foo => :bar, :bar => :baz, :if => lambda { |r| r.foo }
    def attribute(*args)
      if args.first.is_a?(Hash) # :foo => :bar, :bar => :baz
        attr_aliases, conds = args.first.except(:if, :unless), args.first.slice(:if, :unless)
        attr_aliases.each_pair { |k,v| self.attribute(k, conds.merge(:as => v)) }
      else # array of attributes i.e :foo, :bar, :baz
        attr_options = args.extract_options!
        args.each { |name| @_options[:attributes][name] = attr_options }
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
    def glue(data, options={}, &block)
      @_options[:glue].push({ :data => data, :options => options, :block => block })
    end

    # Extends an existing rabl template with additional attributes in the block
    # extends("users/show", :object => @user) { attribute :full_name }
    def extends(file, options={}, &block)
      extend_ops = options.merge(:view_path => options.fetch(:view_path, @_options[:view_path]))
      @_options[:extends].push({ :file => file, :options => extend_ops, :block => block })
    end

    # Includes a helper module with a RABL template
    # helper ExampleHelper
    def helper(*klazzes)
      klazzes.each { |klazz| self.class.__send__(:include, klazz) }
    end
    alias_method :helpers, :helper

    protected

    # Returns a guess at the default object for this template
    # default_object => @user
    def default_object
      if context_scope.respond_to?(:controller)
        controller_name = context_scope.controller.controller_name
        stripped_name = controller_name.split(%r{::|\/}).last
        ivar_object = instance_variable_get("@#{stripped_name}")
        ivar_object if is_object?(ivar_object)
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
      (context_scope.params if context_scope.respond_to?(:params)) || {}
    end

    # Returns data as json embraced with callback when detected
    # format_json({ :foo => "bar" }) => "test({ foo : 'bar' })"
    # format_json("{ foo : "bar" }") => "test({ foo : 'bar' })"
    def format_json(json_output)
      json_engine = Rabl.configuration.json_engine
      json_method = json_engine.respond_to?(:dump) ? 'dump' : 'encode'
      json_output = json_engine.send(json_method, json_output) unless json_output.is_a?(String)
      use_callback = Rabl.configuration.enable_json_callbacks && request_params[:callback].present?
      use_callback ? "#{request_params[:callback]}(#{json_output})" : json_output
    end

    # Augments respond to supporting scope methods
    def respond_to?(name, include_private=false)
      context_scope.respond_to?(name, include_private) ? true : super
    end

    # Supports calling helpers defined for the template scope using method_missing hook
    def method_missing(name, *args, &block)
      context_scope.respond_to?(name, true) ? context_scope.__send__(name, *args, &block) : super
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

    # Caches the results of the block based on object cache_key
    # cache_results { compile_hash(options) }
    def cache_results(&block)
      _cache = @_cache if defined?(@_cache)
      cache_key, cache_options = *_cache || nil
      if template_cache_configured? && cache_key
        if Rails.version =~ /^[4]/
          result_cache_key = cache_key_with_digest(cache_key)
        else # fallback for Rails 3
          result_cache_key = cache_key_simple(cache_key)
        end
        fetch_result_from_cache(result_cache_key, cache_options, &block)
      else # skip caching
        yield
      end
    end

    def cache_key_with_digest(cache_key)
      template = @_options[:template] || @virtual_path

      if Rails.version.to_s >= '4.1'
        digested =  Digestor.digest(name: template, finder: lookup_context)
      else
        digested = Digestor.digest(template, :rabl, lookup_context)
      end

      Array(cache_key) + [
        @_options[:root_name],
        @_options[:format],
        digested
      ]
    rescue NameError => e # Handle case where lookup_context doesn't exist
      raise e unless e.message =~ /lookup_context/
      cache_key_simple(cache_key)
    end # cache_key_with_digest

    def cache_key_simple(key)
      Array(key) + [@_options[:root_name], @_options[:format]]
    end
  end
end
