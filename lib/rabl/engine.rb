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
    def render(parent_scope, locals, &block)
      reset_options!
      @_locals, @_scope = locals, parent_scope
      self.copy_instance_variables_from(@_scope, [:@assigns, :@helpers])
      @_options[:scope] = @_scope
      @_options[:format] ||= self.request_format
      if @_options[:source_location]
        instance_eval(@_source, @_options[:source_location]) if @_source.present?
      else # without source location
        instance_eval(@_source) if @_source.present?
      end
      instance_eval(&block) if block_given?
      cache_results { self.send("to_" + @_options[:format].to_s) }
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true, :child_root => true)
    def to_hash(options={})
      self.object_node.to_hash(options)
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
      result = collection_root_name ? { collection_root_name => to_hash(options) } : to_hash(options)
      Rabl.configuration.plist_engine.dump(result)
    end

    # Returns an xml representation of the data object
    # to_xml(:root => true)
    def to_xml(options={})
      include_root = Rabl.configuration.include_xml_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      xml_options = Rabl.configuration.default_xml_options.merge(:root => data_name(object_data))
      to_hash(options).to_xml(xml_options)
    end

    # Returns a bson representation of the data object
    # to_bson(:root => true)
    def to_bson(options={})
      include_root = Rabl.configuration.include_bson_root
      options = options.reverse_merge(:root => include_root, :child_root => include_root)
      result = if collection_root_name
                 { collection_root_name => to_hash(options) }
               elsif is_collection?(object_data) && object_data.is_a?(Array)
                 { data_name(object_data) => to_hash(options) }
               else
                 to_hash(options)
               end
      Rabl.configuration.bson_engine.serialize(result).to_s
    end

    # Sets the object to be used as the data source for this template
    # object(@user)
    # object @user => :person
    # object @users
    def object(data=false, &block)
      data = @_locals[:object] || data || self.default_object
      @_object_node = Rabl::ObjectNode.new(data, @_options, &block)
    end

    # Sets the object as a collection casted to a simple array
    # collection @users
    # collection @users => :people
    # collection @users, :root => :person
    # collection @users, :object_root => :person
    def collection(data, options={}, &block)
      @_options[:collection_name]  = options[:root] if options[:root]
      @_options[:collection_name]  ||= data.values.first if data.respond_to?(:each_pair)
      @_options[:root_name] = options[:object_root] if options.has_key?(:object_root)
      self.object(data_object(data).to_a, &block) if data
    end

    # Sets the cache key to be used by ActiveSupport::Cache.expand_cache_key
    # cache @user            # calls @user.cache_key
    # cache ['rabl', @user]  # calls @user.cache_key and prefixes with rabl/
    # cache 'user'           # explicit key of 'user'
    # cache 'user', expires_in: 1.hour
    # options is passed through to the cache store
    def cache(key, options = nil)
      key ||= object_data # if called but missing, use object
      @_cache = [key, options]
    end

    protected

    def reset_options!
      @_object_node = nil
    end

    def object_node
      @_object_node ||= Rabl::ObjectNode.new(Object.new, :root_name => false)
    end

    def object_data
      object_node.data if object_node
    end

    # Delegate to object_node for all object related actions
    Rabl::ObjectNode::OBJECT_DELEGATES.each do |option_name|
      class_eval <<-CODE
      def #{option_name}(*args, &block)
        object_node.send('#{option_name}', *args, &block)
      end
      CODE
    end

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


    # Caches the results of the block based on object cache_key
    # cache_results { compile_hash(options) }
    def cache_results(&block)
      _cache = @_cache if defined?(@_cache)
      cache_key, cache_options = *_cache || nil
      if template_cache_configured? && cache_key
        result_cache_key = Array(cache_key) + [@_options[:root_name], @_options[:format]]
        fetch_result_from_cache(result_cache_key, cache_options, &block)
      else # skip caching
        yield
      end
    end

  end
end
