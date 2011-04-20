# TILT Template
if defined?(Tilt)
  class RablTemplate < Tilt::Template
    def initialize_engine
      return if defined?(::Rabl)
      require_template_library 'rabl'
    end

    def prepare
      options = @options.merge(:format => @options[:format])
      @engine = ::Rabl::Engine.new(data, options)
    end

    def evaluate(scope, locals, &block)
      @engine.render(scope, locals, &block)
    end
  end

  Tilt.register 'rabl', RablTemplate
end

# Rails 2.X Template
if defined?(Rails) && Rails.version =~ /^2/
  require 'action_view/base'
  require 'action_view/template'

  module ActionView
    module TemplateHandlers
      class RablHandler < TemplateHandler
        include Compilable

        def compile(template) %{
          ::Rabl::Engine.new(#{template.source.inspect}, { :format => #{template.format.inspect} }).
            render(self, assigns.merge(local_assigns))
        } end
      end
    end
  end

  ActionView::Template.register_template_handler :rabl, ActionView::TemplateHandlers::RablHandler
end

# Rails 3.X Template
if defined?(Rails) && Rails.version =~ /^3/
  require 'action_view/base'
  require 'action_view/template'

  module ActionView
    module Template::Handlers
      class RablHandler < Template::Handler
        include Compilable

        self.default_format = Mime::JSON

        def compile(template) %{
          ::Rabl::Engine.new(#{template.source.inspect}, { :format => #{template.formats.first.inspect} }).
            render(self, assigns.merge(local_assigns))
        } end
      end
    end
  end

  ActionView::Template.register_template_handler :rabl, ActionView::TemplateHandlers::RablHandler
end