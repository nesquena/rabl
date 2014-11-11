module Rabl
  module Partials
    include Helpers
    include Sources

    def partial_as_engine(file, options = {}, &block)
      raise ArgumentError, "Must provide an :object option to render a partial" unless options.has_key?(:object)

      object    = options.delete(:object)

      source, location = fetch_source(file, :view_path => actual_view_path(options))

      options = options.merge(:source => source, :source_location => location, :template => file)
      object_to_engine(object, options, &block)
    end

    private

    def actual_view_path(options = {})
      options[:view_path] || view_path
    end
  end
end
