module Rabl
  class Railtie < Rails::Railtie

    initializer "rabl.initialize" do |app|
      ActiveSupport.on_load(:action_view) do
        Rabl.register!
      end
    end

  end # Railtie
end # Rabl
