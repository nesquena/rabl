require 'action_view/base'
require 'action_view/template'

module ActionView
  module TemplateHandlers
    class JRBHandler < TemplateHandler
      include Compilable

      def compile(template) %{
        ::JRB::Engine.new(assigns.merge(local_assigns), self) do
          #{template.source}
        end.to_#{template.format}
      } end
    end
  end
end

ActionView::Template.register_template_handler :jrb, ActionView::TemplateHandlers::JRBHandler