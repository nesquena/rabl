module Rabl
  class Renderer
    # Defines class method rendering in supported formats
    # Rabl::Renderer.json(@post, 'posts/show')
    # Rabl::Renderer.xml(@post, 'posts/show')
    Rabl::Engine::FORMATS.each do |fmt|
      instance_eval <<-CODE
      def #{fmt}(object, source, options = {})
        new(source, object, options.merge(:format => :#{fmt})).render
      end
      CODE
    end

    attr_reader :object, :options

    # Public: Instantiate a new renderer
    # This is a standalone class used for rendering rabl templates
    # outside of a framework like Rails. You may want to use
    # this when using Rabl to render the request objects passed to
    # message queues.
    #
    # Example:
    #   renderer = Rabl::Renderer.new('template_name', user, { :format => 'json', :view_path => 'app/views' })
    #   renderer.render # => '{"user":{"name": "ivan" }}'
    #
    def initialize(source, object = nil, options = {})
      options = {
        :format     => :json,
        :scope      => self,
        :view_path  => [],
        :template   => source
      }.merge(options)

      @options  = options
      @object   = object

      engine.source = process_source(source)
    end

    # Public: Actually render the template to the requested output format.
    #
    # - context_scope:
    #     Override the render context_scope to the 'context_scope' object. Defaults to self.
    #
    # Returns: And object representing the tranformed object in the requested format.
    #   e.g. json, xml, bson, plist
    def render(context_scope = nil)
      context_scope ||= options[:scope] || self

      set_object_instance_variable if context_scope == self

      locals = { :object => object }.merge(options.fetch(:locals, {}))

      engine.apply(context_scope, locals).render
    end

    protected
      def engine
        @engine ||= Rabl::Engine.new(nil, options)
      end

      # Returns the source given a relative template path
      def process_source(source)
        return source if source.is_a?(String) && source =~ /\n/

        source, _ = engine.fetch_source(source, { :view_path => options[:view_path] })
        source
      end

      # Internal: Sets an instance variable named after the class of `object`
      #
      # Example:
      #   object.class.name # => User
      #   set_object_instance_variable # => @user == object
      #
      def set_object_instance_variable
        instance_variable_set(:"@#{object_model_name}", object)
      end

      # Internal: Returns the model name for an object
      #
      # Example:
      #   object.class.name # => User
      #   object_model_name => "user"
      #
      def object_model_name
        item = object

        is_collection = item.is_a?(Array)
        item = item.first if is_collection

        name = item.class.name.underscore

        name = name.pluralize if is_collection

        name.split("/").last
      end
  end
end
