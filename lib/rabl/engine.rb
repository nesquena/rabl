# frozen_string_literal: true

module Rabl
  class Engine
    include Helpers
    include Partials
    include Helpers::Escaper

    # List of supported rendering formats
    FORMATS = [:json, :xml, :plist, :bson, :msgpack]
    SAFE_FORMATS = FORMATS + [:mpac, :dumpable, :hash]

    # JSONP callback names that are accepted: identifiers, optionally dotted (e.g. "jQuery_1.cb")
    RABL_JSON_CALLBACK_NAME = /\A[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*\z/
    RABL_JSON_CALLBACK_MAX_LENGTH = 128

    # Array#to_xml names its items after the singular of the dasherized root, which misses
    # inflections that match only the underscored name: rules written in underscored form
    # (inflect.irregular 'lesson_progress', 'lessons_progresses', #559), underscored uncountable
    # words (inflect.uncountable 'user_settings') and rules using \w (/^(\w+)ves$/). An XmlArray
    # names them after the singular of the root as given, as rabl does for JSON item roots
    # (to_xml then dasherizes it like any other key), when that singular comes from a newer rule
    # than the one ActiveSupport applies to the dasherized root. Otherwise the name is left to
    # Array#to_xml, so built-in inflections, inflections written with dashes (the workaround in
    # #559) and uncountable words at the end of a name ("animal-species") are named as before.
    # The arrays of one rendering share children_names, so each root's name is worked out once.
    class XmlArray < Array
      def initialize(items, children_names)
        super(items)
        @children_names = children_names
      end

      def to_xml(options = {}, &block)
        root = options[:root].to_s
        unless options[:children] || root.empty?
          renamed = ActiveSupport::XmlMini.rename_key(root, options)
          children = @children_names.fetch([root, renamed]) do |key|
            @children_names[key] = children_name(root, renamed, options)
          end
          options = options.merge(:children => children)
        end
        super(options, &block)
      end

      private

      # The singular of root when it comes from a newer rule than the one ActiveSupport applies
      # to the renamed root, or else the singular of the renamed root, as Array#to_xml names items
      def children_name(root, renamed, options)
        singular = root.singularize
        renamed_singular = renamed.singularize
        xml_mini = ActiveSupport::XmlMini
        return renamed_singular if xml_mini.rename_key(singular, options) == xml_mini.rename_key(renamed_singular, options)

        singular_rule_rank(root) < singular_rule_rank(renamed) ? singular : renamed_singular
      end

      # The position of the singular rule ActiveSupport applies to word. The rules are newest
      # first, so a lower rank is a rule defined later; -1 for an uncountable word, and the rule
      # count when no rule matches.
      def singular_rule_rank(word)
        inflections = ActiveSupport::Inflector.inflections
        return -1 if inflections.uncountables.uncountable?(word)

        rules = inflections.singulars
        rules.index { |(rule, _)| rule.is_a?(Regexp) ? rule.match?(word) : word.include?(rule) } || rules.size
      end
    end
    private_constant :XmlArray

    # Constructs a new ejs engine based on given vars, handler and declarations
    # Rabl::Engine.new("...source...", { :format => "xml", :root => true, :view_path => "/path/to/views" })
    def initialize(source, options = {})
      @_source        = source
      @_settings      = {}
      @_options       = options

      @_view_path     = options[:view_path]
      @_context_scope = options[:scope]
      @_data_item     = options[:data_item]

      @_cache_read_on_render = true
      @_skip_json_callback   = false
      @_rendering = false
    end

    def source=(source)
      @_source = source
    end

    # Renders the representation based on source, object, context_scope and locals
    # Rabl::Engine.new("...source...", { :format => "xml" }).apply(context_scope, { :foo => "bar", :object => @user })
    def apply(context_scope, locals, &block)
      locals = locals.dup unless locals.nil?

      set_instance_variables!(context_scope, locals)

      reset_settings!
      reset_options!

      # A block (child, glue, or extends/partial with a block) is identified by its
      # location and the engine of the template that defined it
      @_block_identity    = block && [block, @_options[:parent_engine]]
      @_template_identity = nil
      @_identity_memo     = nil

      # A cache key belongs to one render; the template sets it again
      remove_instance_variable(:@_cache_key) if defined?(@_cache_key)
      @_full_cache_key = nil

      eval_source(locals, &block)

      instance_exec(root_object, &block) if block_given?

      self
    end

    # Renders the representation based on a previous apply
    # Rabl::Engine.new("...source...", { :format => "xml" }).apply(context_scope, { :foo => "bar", :object => @user }).render
    def render(context_scope = nil, locals = nil, &block)
      apply(context_scope, locals, &block) if context_scope || locals || block

      return cache_results { send("to_#{@_options[:format]}") } unless @_options[:format].to_s == "json"

      # The JSONP callback comes from the request, so it is added after the cache.
      result = cache_results do
        begin
          @_skip_json_callback = true
          to_json
        ensure
          @_skip_json_callback = false
        end
      end

      rabl_wrap_json_callback(result)
    end

    def cache_key
      return unless defined?(@_cache_key)

      @_full_cache_key ||= begin
        cache_key = Array(@_cache_key) + [@_options[:root_name], @_options[:format]]
        # a nested engine caches its output before it is escaped, so it gets its own key
        cache_key << 'nested' if @_options[:nested]

        if digestor_available? && respond_to?(:lookup_context) && lookup_context
          template = @_options[:template] || @virtual_path

          digest =
            if Rails.version.to_s =~ /^[678]/
              Digestor.digest(name: template, finder: lookup_context, format: :rabl)
            elsif Gem::Version.new(Rails.version) >= Gem::Version.new('4.1')
              Digestor.digest(:name => template, :finder => lookup_context)
            else
              Digestor.digest(template, :rabl, lookup_context)
            end

          cache_key << digest
          # The digest covers the template source, but not the block that defines this engine
          if @_block_identity
            block, parent = @_block_identity
            key = [:block, block, parent && parent.rabl_template_identity]
            cache_key << rabl_memoized_digest(key) { TemplateCacheKey.digest(rabl_block_identity) }
          end
        else
          cache_key << rabl_template_identity
        end

        cache_key << "collection" if is_collection?(root_object)
        cache_key.concat(TemplateCacheKey.shape(@_options))

        cache_key
      end
    end

    # Returns a hash representation of the data object
    # to_hash(:root => true, :child_root => true)
    def to_hash(options = {})
      # options given to the engine (e.g. Rabl::Renderer's :root) win over the format defaults
      options.merge!(@_options)

      data = root_object

      options[:root_name] = determine_object_root(data, root_name, options[:root])
      options[:template_engine] = self

      @_rendering = true
      result =
        if is_object?(data) || !data # object @user
          Builder.new(data, @_settings, options).to_hash
        elsif is_collection?(data) # collection @users
          MultiBuilder.new(data, @_settings, options).to_a
        end

      # A nested engine (child, glue, extends, partial) is escaped with the engine it is part of
      result = escape_output(result) if Rabl.configuration.escape_all_output && !@_options[:nested]

      result
    ensure
      @_rendering = false
    end

    def to_dumpable(options = {})
      options.reverse_merge!({ :child_root => Rabl.configuration.include_child_root })

      result = to_hash(options)
      result = { collection_root_name => result } if collection_root_name
      result
    end

    # Returns a json representation of the data object
    # to_json(:root => true)
    def to_json(options = {})
      options.reverse_merge!({ :root => Rabl.configuration.include_json_root })
      result = to_dumpable(options)
      rabl_wrap_json_callback(format_json(result))
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
      load_xml_support!

      options = {
        :root       => (include_root = Rabl.configuration.include_xml_root),
        :child_root => include_root && Rabl.configuration.include_child_root
      }.merge(options)

      xml_options = Rabl.configuration.default_xml_options.merge(:root => collection_root_name || root_name)

      result = to_hash(options)

      # Name the items after the object root and unwrap them, or Array#to_xml wraps each
      # { object_root => ... } item again in the singular collection root (#581)
      if result.is_a?(Array) && is_name_value?(object_root_name)
        xml_options[:children] = object_root_name.to_s
        result = result.map { |item| item.is_a?(Hash) && item.key?(object_root_name) ? item[object_root_name] : item }
      end

      xml_arrays(result).to_xml(xml_options)
    end

    # Returns a bson representation of the data object
    # to_bson(:root => true)
    def to_bson(options = {})
      options = { :root => Rabl.configuration.include_bson_root }.merge(options)
      result = to_dumpable(options)

      if !collection_root_name && is_collection?(root_object) && root_object.is_a?(Array)
        result = { root_name => result }
      end

      bson_engine = Rabl.configuration.bson_engine
      if bson_engine.respond_to?(:serialize)
        # BSON < 2.0 API
        bson_engine.serialize(result).to_s
      else
        # BSON >= 2.0 API
        result.to_bson.to_s
      end
    end

    # Sets the object to be used as the data source for this template
    # object(@user)
    # object @user => :person
    # object @users
    def object(template_data)
      current_data  = (@_locals[:object].nil? || template_data == false) ? template_data : @_locals[:object]
      @_data_object = data_object(current_data)
      @_root_name_data = template_data.is_a?(Hash) && !current_data.is_a?(Hash) ? template_data : current_data
      if @_root_name_data.is_a?(Hash)
        alias_form = @_root_name_data.size == 1 # object @user => :person
        @_root_name_data = @_root_name_data.values.first
        # object @user => "person" names the root the same way
        @_root_name_data = @_root_name_data.to_sym if alias_form && @_root_name_data.is_a?(String)
      end

      # If we turn this around, `@_root_name_date ==` may trigger data to be loaded unnecessarily.
      # TODO: is nil a different semantic? otherwise don't use `false ==`, use !
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
    # collection @users => :people, :object_root => false
    def collection(data, options = {})
      data, options = split_folded_options(data, options, [:root, :object_root])

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
        warn_if_rendering(:attribute)

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
      warn_if_rendering(:node)

      if name.is_a?(Hash) && name.present? && options.blank? && (name.keys - [:if, :unless]).empty?
        name, options = nil, name # node(:if => lambda { ... }) { ... } has conditions but no name
      end

      @_settings[:node] << { :name => name, :options => options, :block => block }
    end
    alias_method :code, :node

    # Creates a child node that is included in json output
    # child(@user) { attribute :full_name }
    # child(:posts => :items, :if => lambda { ... }) { attribute :title }
    def child(data, options = {}, &block)
      warn_if_rendering(:child)

      data, options = split_folded_options(data, options, [:if, :unless, :root, :object_root])

      @_settings[:child] << { :data => data, :options => options, :block => block }
    end

    # Glues data from a child node to the json_output
    # glue(@user) { attribute :full_name => :user_full_name }
    def glue(data, options = {}, &block)
      warn_if_rendering(:glue)

      data, options = split_folded_options(data, options, [:if, :unless])

      @_settings[:glue] << { :data => data, :options => options, :block => block }
    end

    # Extends an existing rabl template with additional attributes in the block
    # extends("users/show", :object => @user) { attribute :full_name }
    def extends(file, options = {}, &block)
      return if warn_if_rendering(:extends)

      options.reverse_merge!({ :view_path => options[:view_path] || view_path })

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

    # Returns the key given to `cache` in the template, if any
    def rabl_cache_key_parts
      defined?(@_cache_key) ? Array(@_cache_key) : []
    end

    # Identifies the template for cache keys: a digest of its location, the view path its
    # partials resolve from, its source and its block
    def rabl_template_identity
      @_template_identity ||= begin
        location = @_options[:source_location]

        if @_options[:parent_engine] && (location || !@_source)
          # Within one render, a template's location determines its source
          # (nested lookups rather than an Array key, as this runs for every item)
          memo = (rabl_identity_memo[location] ||= {})
          memo = (memo[view_path] ||= {})

          if @_block_identity
            block, parent = @_block_identity
            memo = (memo[block] ||= {})
            memo[parent && parent.rabl_template_identity] ||= rabl_template_digest
          else
            memo[:template] ||= rabl_template_digest
          end
        else
          rabl_template_digest
        end
      end
    end

    protected
      def rabl_template_digest
        root = TemplateCacheKey.root
        view_paths = Array(view_path).map { |path| TemplateCacheKey.path(path, root) }
        TemplateCacheKey.digest([TemplateCacheKey.path(@_options[:source_location], root), view_paths, @_source, rabl_block_identity(root)])
      end

      # Returns the digest for key, computing it once per render: the memo is kept by the
      # top-level engine, so the items of a collection share their sub-templates' digests
      def rabl_memoized_digest(key)
        rabl_identity_memo[key] ||= yield
      end

      def rabl_identity_memo
        @_identity_memo ||= (parent = @_options[:parent_engine]) ? parent.rabl_identity_memo : {}
      end

      def rabl_template_engine
        self
      end

      # Identifies the block that defines this engine, if any: its location and the
      # template that defined it
      def rabl_block_identity(root = TemplateCacheKey.root)
        return unless @_block_identity

        block, parent = @_block_identity
        location = block.source_location
        location &&= [TemplateCacheKey.path(location[0], root), location[1], location.size > 2 ? location[2] : TemplateCacheKey.column(block)]
        [location, parent && parent.rabl_template_identity]
      end

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

      # Returns data as json
      # format_json({ :foo => "bar" }) => "{\"foo\":\"bar\"}"
      def format_json(json_output)
        unless json_output.is_a?(String)
          json_engine = Rabl.configuration.json_engine
          json_output = if defined?(::Oj) && json_engine.equal?(::Oj)
            oj_options = Rabl.configuration.oj_dump_options
            oj_options.empty? ? ::Oj.dump(json_output) : ::Oj.dump(json_output, oj_options)
          elsif json_engine.respond_to?(:dump)
            json_engine.dump(json_output)
          else
            json_engine.encode(json_output)
          end
        end

        json_output
      end

      # Returns json embraced with the request's callback when callbacks are enabled
      # and the callback name is valid, otherwise the json unchanged
      # rabl_wrap_json_callback("{}") => "/**/test({})"
      def rabl_wrap_json_callback(json)
        callback = rabl_json_callback_name unless @_skip_json_callback
        callback ? "/**/#{callback}(#{json})" : json
      end

      # Returns the request's callback parameter if callbacks are enabled and it is a valid name
      def rabl_json_callback_name
        return unless Rabl.configuration.enable_json_callbacks

        callback = request_params[:callback]
        return unless callback.is_a?(String) && callback.length <= RABL_JSON_CALLBACK_MAX_LENGTH
        return unless callback.ascii_only? && callback =~ RABL_JSON_CALLBACK_NAME

        callback
      end

      # Augments respond to supporting context_scope methods
      def respond_to?(name, include_private = false)
        context_scope.respond_to?(name, include_private) || super
      end

      # Supports calling helpers defined for the template context_scope using method_missing hook
      def method_missing(name, *args, **kwargs, &block)
        return super unless context_scope.respond_to?(name, true)

        if kwargs.empty?
          context_scope.__send__(name, *args, &block)
        else
          context_scope.__send__(name, *args, **kwargs, &block)
        end
      end

      def copy_instance_variables_from(object, exclude = []) #:nodoc:
        vars = object.instance_variables - exclude
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
        defined?(Rails) && Rails.version =~ /^[45678]/
      end

      def valid_format?(format)
        SAFE_FORMATS.include?(format.to_sym) && respond_to?("to_#{format}")
      end

      def set_instance_variables!(context_scope, locals)
        @_context_scope = context_scope
        @_locals        = locals || {}

        copy_instance_variables_from(context_scope, [:@assigns, :@helpers])

        @_options[:format] ||= request_format

        # Prevent calls to inherited methods `to_yaml`, `to_enum`, etc.
        @_options[:format] = 'json' unless valid_format?(@_options[:format])

        set_locals(@_locals)
      end

      def set_locals(locals)
        locals.merge!(locals.delete(:locals) || {})
        locals.each { |key, value| instance_variable_set(:"@#{key}", value) }
      end

      def eval_source(locals, &block)
        return unless @_source.present?

        # One method per source and location, so blocks report the file that defined them
        msg = "cached_source_#{[@_source, @_options[:source_location]].hash.abs}"

        unless self.respond_to? msg then
          src = "def #{msg} locals, &block\n#{@_source}\nend"

          if @_options[:source_location]
            self.class.class_eval(src, @_options[:source_location])
          else
            self.class.class_eval(src)
          end
        end

        send msg, locals, &block
      end

      # Hash#to_xml and Array#to_xml come from ActiveSupport (which uses the builder gem);
      # Rails loads them, but other apps may not have.
      def load_xml_support!
        return if defined?(::Builder::XmlMarkup) && {}.respond_to?(:to_xml) && [].respond_to?(:to_xml)

        require 'active_support/core_ext/array/conversions'
        require 'active_support/core_ext/hash/conversions'

        begin
          require 'builder' unless defined?(::Builder::XmlMarkup)
        rescue LoadError
          raise LoadError, "rabl needs the builder gem to render XML; add `gem 'builder'` to your Gemfile"
        end
      end

      # Returns a copy of the data with each Array in it, at any depth, as an XmlArray; arrays
      # with a to_xml of their own are left as they are
      def xml_arrays(data, children_names = {})
        case data
        when Hash
          copy = data.dup
          data.each { |key, value| copy[key] = xml_arrays(value, children_names) }
          copy
        when Array
          return data unless data.method(:to_xml).owner == Array

          XmlArray.new(data.map { |value| xml_arrays(value, children_names) }, children_names)
        else
          data
        end
      end

      # attribute, node, child, glue and extends build the template's settings, which are read while
      # it renders (#477). Called then (e.g. inside a node block), they warn; attribute, node, child
      # and glue work as before, and extends is ignored, since its settings (view path included)
      # would otherwise be the node's value. Returns true when the template is rendering.
      # ceiling: warns on every call, so a misuse inside a large collection repeats the warning;
      # dedupe by call site if that turns out to be noisy.
      def warn_if_rendering(method_name)
        return false unless @_rendering

        effect = method_name == :extends ? "is ignored" : "changes the template for the rest of the render"
        site = caller.find { |line| !line.start_with?(__FILE__) }.to_s.sub(/:in .*\z/m, '')
        Kernel.warn "rabl: #{method_name} called while the template renders (e.g. inside a node block) at #{site} " \
                    "#{effect}; to render another template there, use partial(\"template\", :object => object)"
        true
      end

      # Ruby folds `child :posts => :items, :if => cond` into a single hash, so the options
      # arrive inside the data. They are split out only when no options were given separately
      # and what remains is a single alias (`data => name`); any other hash is left as data.
      # split_folded_options({ :posts => :items, :if => true }, {}, [:if]) => [{ :posts => :items }, { :if => true }]
      def split_folded_options(data, options, option_keys)
        return [data, options] unless data.is_a?(Hash) && options.blank?

        found = data.keys & option_keys
        alias_data = data.except(*found)
        return [data, options] unless found.any? && alias_data.size == 1 && is_name_value?(alias_data.values.first)

        [alias_data, data.slice(*found)]
      end
  end
end
