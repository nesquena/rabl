module Rabl
  class Railtie < Rails::Railtie
    initializer "rabl.initialize" do |app|
      ActiveSupport.on_load(:action_view) do
        Rabl.register!

        # Inject dependency tracker for :rabl
        if Rails.version =~ /^[45]/
          require 'action_view/dependency_tracker'
          ActionView::DependencyTracker.register_tracker :rabl, Rabl::Tracker
        end
      end
    end
  end # Railtie
end # Rabl
