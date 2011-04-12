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