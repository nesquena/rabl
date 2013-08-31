# TILT Template
if defined?(Tilt)
  class RablTemplate < Tilt::Template
    def initialize_engine
      return if defined?(::Rabl)
      require_template_library 'rabl'
    end

    def prepare
      options = @options.merge(:format => @options[:format], :source_location => file)
      @engine = ::Rabl::Engine.new(data, options)
    end

    def evaluate(scope, locals, &block)
      @engine.render(scope, locals, &block)
    end
  end

  Tilt.register 'rabl', RablTemplate
end

# Rails 2.X Template
if defined?(ActionView) && defined?(Rails) && Rails.version.to_s =~ /^2/
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

# Rails 3.X / 4.X Template
if defined?(ActionView) && defined?(Rails) && Rails.version.to_s =~ /^[34]/
  module ActionView
    module Template::Handlers
      class Rabl
        class_attribute :default_format
        self.default_format = Mime::JSON

        def self.call(template)
          source = template.source

          %{ ::Rabl::Engine.new(#{source.inspect}).
              render(self, assigns.merge(local_assigns)) }
        end # call
      end # rabl class
    end # handlers
  end

  ActionView::Template.register_template_handler :rabl, ActionView::Template::Handlers::Rabl
end