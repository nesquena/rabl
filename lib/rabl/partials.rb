module Rabl
  module Partials
    include Helpers
    include Sources

    def partial_as_engine(file, options = {}, &block)
      raise ArgumentError, "Must provide an :object option to render a partial" unless options.has_key?(:object)

      object    = options.delete(:object)
      view_path = options[:view_path] || self.view_path

      source, location = fetch_source(file, :view_path => view_path)

      options = options.merge(:source => source, :source_location => location, :template => file)
      object_to_engine(object, options, &block)
    end
  end
end
