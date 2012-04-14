module Rabl
  class Renderer

    class << self
      def json(object, source, options = {})
        new(source, object, options.merge(:format => :json)).render
      end

      def xml(object, source, options = {})
        new(source, object, options.merge(:format => :xml)).render
      end

      def hash(object, source, options = {})
        new(source, object, options.merge(:format => :hash)).render
      end

      def plist(object, source, options = {})
        new(source, object, options.merge(:format => :plist)).render
      end

      def bson(object, source, options = {})
        new(source, object, options.merge(:format => :bson)).render
      end

      def msgpack(object, source, options = {})
        new(source, object, options.merge(:format => :msgpack)).render
      end
    end

    # Public: Instantiate a new renderer
    # This is a standalone class used for rendering rabl templates
    # outside of a framework like Rails. You may want to use
    # this when using Rabl to render the request objects passed to
    # message queues.
    #
    # Example:
    #   renderer = Rabl::Renderer.new('template_name', user, { :format => 'json', :view_path => 'app/views' })
    #   renderer.render # => "{\"user\":{\"name\":\"ivan\"}}"
    #
    attr_reader :object, :options
    def initialize(source, object = nil, options = {})
      options = {
        :format => :json,
        :scope => self,
        :view_path => []
      }.update(options)
      @options = options

      @object = object

      engine.source = self.process_source(source)
    end

    # Public: Actually render the template to the requested output format.
    #
    # - scope:
    #     Override the render scope to the 'scope' object. Defaults to self.
    #
    # Returns: And object representing the tranformed object in the requested format.
    #   e.g. json, xml, bson, plist
    def render(scope = nil)
      scope = scope ? scope : options.delete(:scope) || self
      set_instance_variable(object) if scope == self
      engine.render(scope, options.fetch(:locals, {}))
    end

    protected

    def engine
      @engine ||= Rabl::Engine.new(nil, options)
    end

    def process_source(source)
      unless source.is_a?(String) && source =~ /\n/
        source, _ = engine.fetch_source(source, {:view_path => options[:view_path]})
      end
      return source
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

    def model_name(object)
      item = object.is_a?(Array) ? object.first : object
      name = item.class.name.underscore
      object.is_a?(Array) ? name.pluralize : name
    end

  end
end
