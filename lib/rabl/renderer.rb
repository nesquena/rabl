module Rabl
  class Renderer

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
