module Rabl
  class Renderer < Engine

    attr_reader :file, :object, :options
    def initialize(file, object, options = {})
      options = {:format => :json}.update(options)
      @file, @object, @options = file, object, options

      view_path = options.delete(:view_path)
      source, location = engine.fetch_source(file, :view_path => view_path)
      engine.source = source
    end

    def render
      set_instance_variable(object)
      engine.render(self, {})
    end

    protected

    def engine
      @engine ||= Engine.new(nil, options)
    end

    def set_instance_variable(object)
      name = model_name(object).split('/').last
      instance_variable_set(:"@#{name}", object)
    end

  end
end
