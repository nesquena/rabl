module Rabl
  class Engine
    include Helpers
    include Partials
    include Helpers::Escaper

    # List of supported rendering formats
    FORMATS = [:json, :xml, :plist, :bson, :msgpack]

    # Constructs a new ejs engine based on given vars, handler and declarations
    # Rabl::Engine.new("...source...", { :format => "xml", :root => true, :view_path => "/path/to/views" })
    def initialize(source, options = {})
      @_source        = source
      @_settings      = {}
      @_options       = options

      @_view_path     = options[:view_path]
      @_context_scope = options[:scope]

      @_cache_read_on_render = true
    end

    def source=(source)
      @_source = source
    end

    # Renders the representation based on source, object, context_scope and locals
    # Rabl::Engine.new("...source...", { :format => "xml" }).apply(context_scope, { :foo => "bar", :object => @user })
    def apply(context_scope, locals, &block)
      set_instance_variables!(context_scope, locals)

      reset_settings!
      reset_options!

      eval_source(locals, &block)

      instance_exec(root_object, &block) if block_given?

      self
    end

    # Renders the representation based on a previous apply
    # Rabl::Engine.new("...source...", { :format => "xml" }).apply(context_scope, { :foo => "bar", :object => @user }).render
    def render(context_scope = nil, locals = nil, &block)
      apply(context_scope, locals, &block) if context_scope || locals || block

      cache_results do
        send("to_#{@_options[:format]}")
      end
    end

    def cache_key
      return unless defined?(@_cache_key)

      @_full_cache_key ||= begin
        cache_key = Array(@_cache_key) + [@_options[:root_name], @_options[:format]]

        if digestor_available? && respond_to?(:lookup_context) && lookup_context
          template = @_options[:template] || @virtual_path

          digest = \
            if Gem::Version.new(Rails.version) >= Gem::Version.new('4.1')
              Digestor.digest(:name => template, :finder => lookup_context)
            else
              Digestor.digest(template, :rabl, lookup_context)
            end

          cache_key << digest
        end

        cache_key
      end
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true, :child_root => true)
    def to_hash(options = {})
      options = @_options.merge(options)

      data = root_object

      options[:root_name] = determine_object_root(data, root_name, options[:root])

      result = \
        if is_object?(data) || !data # object @user
          Builder.new(data, @_settings, options).to_hash
        elsif is_collection?(data) # collection @users
          MultiBuilder.new(data, @_settings, options).to_a
        end

      result = escape_output(result) if Rabl.configuration.escape_all_output

      result
    end

    def to_dumpable(options = {})
      options = {
        :child_root => Rabl.configuration.include_child_root
      }.merge(options)

      result = to_hash(options)
      result = { collection_root_name => result } if collection_root_name
      result
    end

    # Returns a json representation of the data object
    # to_json(:root => true)
    def to_json(options = {})
      options = { :root => Rabl.configuration.include_json_root }.merge(options)
      result = to_dumpable(options)
      format_json(result)
    end

    # Returns a msgpack representation of the data object
    # to_msgpack(:root => true)
    def to_msgpack(options = {})
      options = { :root => Rabl.configuration.include_msgpack_root }.merge(options)
      result = to_dumpable(options)
      Rabl.configuration.msgpack_engine.pack(result)
    end
    alias_method :to_mpac, :to_msgpack

    # Returns a plist representation of the data object
    # to_plist(:root => true)
    def to_plist(options = {})
      options = { :root => Rabl.configuration.include_plist_root }.merge(options)
      result = to_dumpable(options)
      Rabl.configuration.plist_engine.dump(result)
    end

    # Returns an xml representation of the data object
    # to_xml(:root => true)
    def to_xml(options = {})
      options = {
        :root       => (include_root = Rabl.configuration.include_xml_root),
        :child_root => include_root && Rabl.configuration.include_child_root
      }.merge(options)

      xml_options = Rabl.configuration.default_xml_options.merge(:root => collection_root_name || root_name)

      result = to_hash(options)

      result.to_xml(xml_options)
    end

    # Returns a bson representation of the data object
    # to_bson(:root => true)
    def to_bson(options = {})
      options = { :root => Rabl.configuration.include_bson_root }.merge(options)
      result = to_dumpable(options)

      if !collection_root_name && is_collection?(root_object) && root_object.is_a?(Array)
        result = { root_name => result }
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
      @_root_name_data = template_data.is_a?(Hash) && !current_data.is_a?(Hash) ? template_data : current_data
      @_root_name_data = @_root_name_data.values.first if @_root_name_data.is_a?(Hash)

      # If we turn this around, `@_root_name_date ==` may trigger data to be loaded unnecessarily.
      if false == @_root_name_data
        @_object_root_name = false
        @_collection_name = false
      end
    end

    # Returns the current object that is the topic of this template
    # Can be the collection or the object depending on topic assigned
    # root_object => @user
    def root_object
      return @_data_object if defined?(@_data_object)

      data = @_locals[:object].nil? ? default_object : @_locals[:object]
      @_data_object = data_object(data)
    end

    def root_name
      return @_data_name if defined?(@_data_name)

      @_data_name = @_options[:object_root_name] || begin
        data = defined?(@_root_name_data) ? @_root_name_data : (@_locals[:object].nil? ? root_object : @_locals[:object])
        data_name(data)
      end
    end

    # Sets the object as a collection casted to a simple array
    # collection @users
    # collection @users => :people
    # collection @users, :root => :person
    # collection @users, :object_root => :person
    def collection(data, options = {})
      @_collection_name = options[:root] if options[:root]
      @_collection_name ||= data.values.first if data.is_a?(Hash)

      @_object_root_name = options[:object_root] if options.has_key?(:object_root)

      object(data_object(data) || [])
    end

    # Sets the cache key to be used by ActiveSupport::Cache.expand_cache_key
    # cache @user            # calls @user.cache_key
    # cache ['rabl', @user]  # calls @user.cache_key and prefixes with rabl/
    # cache 'user'           # explicit key of 'user'
    # cache                  # uses the current item within a collection
    # cache 'user', expires_in: 1.hour
    # options is passed through to the cache store
    def cache(key = nil, options = {})
      key ||= root_object # if called but missing, use object
      @_cache_key     = key
      @_cache_options = options
    end

    # Indicates an attribute or method should be included in the json output
    # attribute :foo, :as => "bar"
    # attribute :foo => :bar, :bar => :baz
    # attribute :foo => :bar, :bar => :baz, :if => lambda { |r| r.foo }
    def attribute(*args)
      if args.first.is_a?(Hash) # :foo => :bar, :bar => :baz
        attr_aliases  = args.first.except(:if, :unless)
        conditions    = args.first.slice(:if, :unless)

        attr_aliases.each do |key, as|
          attribute(key, conditions.merge(:as => as))
        end
      else # array of attributes i.e :foo, :bar, :baz
        options = args.extract_options!
        args.each do |name|
          @_settings[:attributes] << { :name => name, :options => options }
        end
      end
    end
    alias_method :attributes, :attribute

    # Creates an arbitrary node that is included in the json output.
    # node(:foo) { "bar" }
    # node(:foo, :if => lambda { ... }) { "bar" }
    def node(name = nil, options = {}, &block)
      @_settings[:node] << { :name => name, :options => options, :block => block }
    end
    alias_method :code, :node

    # Creates a child node that is included in json output
    # child(@user) { attribute :full_name }
    def child(data, options = {}, &block)
      @_settings[:child] << { :data => data, :options => options, :block => block }
    end

    # Glues data from a child node to the json_output
    # glue(@user) { attribute :full_name => :user_full_name }
    def glue(data, options = {}, &block)
      @_settings[:glue] << { :data => data, :options => options, :block => block }
    end

    # Extends an existing rabl template with additional attributes in the block
    # extends("users/show", :object => @user) { attribute :full_name }
    def extends(file, options = {}, &block)
      options = { :view_path => options[:view_path] || view_path }.merge(options)

      @_settings[:extends] << { :file => file, :options => options, :block => block }
    end

    # Includes a helper module with a RABL template
    # helper ExampleHelper
    def helper(*klasses)
      klasses.each { |klass| self.class.__send__(:include, klass) }
    end
    alias_method :helpers, :helper

    # Returns a hash representing the partial
    # partial("users/show", :object => @user)
    # options must have :object
    # options can have :view_path, :child_root, :root
    def partial(file, options = {}, &block)
      engine = partial_as_engine(file, options, &block)
      engine = engine.render if engine.is_a?(Engine)
      engine
    end

    # Disables reading (but not writing) from the cache when rendering.
    def cache_read_on_render=(read)
      @_cache_read_on_render = read
    end

    def cache_read_on_render?
      @_cache_read_on_render
    end

    protected
      # Returns a guess at the default object for this template
      # default_object => @user
      def default_object
        return unless context_scope.respond_to?(:controller)

        controller_name = context_scope.controller.controller_name
        stripped_name = controller_name.split(%r{::|\/}).last
        ivar_object = instance_variable_get("@#{stripped_name}")
        ivar_object if is_object?(ivar_object)
      end

      # Returns a guess at the format in this context_scope
      # request_format => "xml"
      def request_format
        format = request_params[:format]

        if format.nil? && context_scope.respond_to?(:request)
          request = context_scope.request
          format = request.format.to_sym.to_s if request.respond_to?(:format)
        end

        format = "json" unless format && respond_to?("to_#{format}")

        format
      end

      # Returns the request parameters if available in the context_scope
      # request_params => { :foo => "bar" }
      def request_params
        (context_scope.params if context_scope.respond_to?(:params)) || {}
      end

      # Returns data as json embraced with callback when detected
      # format_json({ :foo => "bar" }) => "test({ foo : 'bar' })"
      # format_json("{ foo : "bar" }") => "test({ foo : 'bar' })"
      def format_json(json_output)
        unless json_output.is_a?(String)
          json_engine = Rabl.configuration.json_engine
          json_output = if json_engine.respond_to?(:dump)
            json_engine.dump(json_output)
          else
            json_engine.encode(json_output)
          end
        end

        use_callback = Rabl.configuration.enable_json_callbacks && request_params[:callback].present?
        json_output = "#{request_params[:callback]}(#{json_output})" if use_callback

        json_output
      end

      # Augments respond to supporting context_scope methods
      def respond_to?(name, include_private = false)
        context_scope.respond_to?(name, include_private) || super
      end

      # Supports calling helpers defined for the template context_scope using method_missing hook
      def method_missing(name, *args, &block)
        context_scope.respond_to?(name, true) ? context_scope.__send__(name, *args, &block) : super
      end

      def copy_instance_variables_from(object, exclude = []) #:nodoc:
        vars = object.instance_variables.map(&:to_s) - exclude.map(&:to_s)
        vars.each { |name| instance_variable_set(name, object.instance_variable_get(name)) }
      end

      def reset_settings!
        @_settings[:attributes]  = []
        @_settings[:node]        = []
        @_settings[:child]       = []
        @_settings[:glue]        = []
        @_settings[:extends]     = []
      end

      # Resets the options parsed from a rabl template.
      def reset_options!
        @_options[:root_name]   = nil
        @_options[:read_multi]  = false
        @_options[:scope]       = context_scope
      end

      # Caches the results of the block based on object cache_key
      # cache_results { compile_hash(options) }
      def cache_results(&block)
        return yield unless template_cache_configured? && defined?(@_cache_key)

        if cache_read_on_render?
          fetch_result_from_cache(cache_key, @_cache_options, &block)
        else
          write_result_to_cache(cache_key, @_cache_options, &block)
        end
      end

      def digestor_available?
        defined?(Rails) && Rails.version =~ /^[45]/
      end

      def set_instance_variables!(context_scope, locals)
        @_context_scope = context_scope
        @_locals        = locals || {}

        copy_instance_variables_from(context_scope, [:@assigns, :@helpers])

        @_options[:format] ||= request_format

        set_locals(@_locals)
      end

      def set_locals(locals)
        locals.merge!(locals.delete(:locals) || {})
        locals.each { |key, value| instance_variable_set(:"@#{key}", value) }
      end

      def eval_source(locals, &block)
        # Note: locals and block may be used by the eval'ed source

        return unless @_source.present?

        if @_options[:source_location]
          instance_eval(@_source, @_options[:source_location])
        else
          instance_eval(@_source)
        end
      end
    end
end
