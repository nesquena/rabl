# frozen_string_literal: true

module Rabl
  class Railtie < Rails::Railtie
    initializer "rabl.initialize" do |app|
      # Force Rails to load view templates even in API mode
      # Stolen shamelessly from jbuilder: https://github.com/rails/jbuilder/blob/master/lib/jbuilder/railtie.rb
      module ::ActionController
        module ApiRendering
          include ActionView::Rendering
        end
      end

      ActiveSupport.on_load :action_controller do
        if self == ActionController::API
          include ActionController::Helpers
          include ActionController::ImplicitRender
        end
      end

      ActiveSupport.on_load(:action_view) do
        Rabl.register!

        # Inject dependency tracker for :rabl
        require 'action_view/dependency_tracker'
        ActionView::DependencyTracker.register_tracker :rabl, Rabl::Tracker
      end
    end
  end # Railtie
end # Rabl
