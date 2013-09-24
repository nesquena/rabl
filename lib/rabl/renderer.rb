module Rabl
  class Renderer
    # Defines class method rendering in supported formats
    # Rabl::Renderer.json('posts/show', @post)
    # Rabl::Renderer.xml('posts/show', @post)
    Rabl::Engine::FORMATS.each do |fmt|
      instance_eval <<-CODE
      def #{fmt}(object, source, options = {})
        new(source, object, options.merge(:format => :#{fmt})).render
      end
      CODE
    end

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
    attr_reader :object, :options
    def initialize(source, object = nil, options = {})
      options = {
        :format => :json,
        :scope => self,
        :view_path => [],
        :template => source
      }.update(options)

      @options = options
      @object = object

      engine.source = self.process_source(source)
    end

    # Public: Actually render the template to the requested output format.
    #
    # - context_scope:
    #     Override the render scope to the 'scope' object. Defaults to self.
    #
    # Returns: And object representing the tranformed object in the requested format.
    #   e.g. json, xml, bson, plist
    def render(context_scope = nil)
      context_scope = context_scope ? context_scope : options.delete(:scope) || self
      set_instance_variable(object) if context_scope == self
      locals = options.fetch(:locals, {}).reverse_merge(:object => object)
      engine.render(context_scope, locals)
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
    #   set_instance_variable(object) # => @user
    #
    def set_instance_variable(object)
      name = model_name(object).split('/').last
      instance_variable_set(:"@#{name}", object)
    end

    # Internal: Returns the model name for an object
    #
    # Example:
    #  model_name(@post) => "@post"
    #
    def model_name(object)
      item = object.is_a?(Array) ? object.first : object
      name = item.class.name.underscore
      object.is_a?(Array) ? name.pluralize : name
    end

  end
end
