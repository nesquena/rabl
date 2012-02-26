module Rabl
  module Partials
    include Rabl::Helpers

    # Renders a partial hash based on another rabl template
    # partial("users/show", :object => @user)
    # options must have :object
    # options can have :view_path, :child_root, :root
    def partial(file, options={}, &block)
      raise ArgumentError, "Must provide an :object option to render a partial" unless options.has_key?(:object)
      object, view_path = options.delete(:object), options.delete(:view_path)
      source, location = self.fetch_source(file, :view_path => view_path)
      engine_options = options.merge(:source => source, :source_location => location)
      self.object_to_hash(object, engine_options, &block)
    end

    # Returns a hash based representation of any data object given ejs template block
    # object_to_hash(@user) { attribute :full_name } => { ... }
    # object_to_hash(@user, :source => "...") { attribute :full_name } => { ... }
    # object_to_hash([@user], :source => "...") { attribute :full_name } => { ... }
    # options must have :source (rabl file contents)
    # options can have :source_location (source filename)
    def object_to_hash(object, options={}, &block)
      return object unless is_object?(object) || is_collection?(object)
      return [] if is_collection?(object) && object.blank? # empty collection
      engine_options = options.merge(:format => "hash", :root => (options[:root] || false))
      Rabl::Engine.new(options[:source], engine_options).render(@_scope, :object => object, &block)
    end

    # Returns source for a given relative file
    # fetch_source("show", :view_path => "...") => "...contents..."
    def fetch_source(file, options={})
      Rabl.source_cache(file, options[:view_path]) do
        if defined? Padrino
          root_path = Padrino.root
          # use Padrino's own template resolution mechanism
          file_path, _ = @_scope.instance_eval { resolve_template(file) }
          # Padrino chops the extension, stitch it back on
          file_path = File.join(@_scope.settings.views, (file_path.to_s + ".rabl"))
        elsif defined? Rails
          if defined?(@_scope) && @_scope.respond_to?(:find_template)
            # use Rails's own template resolution mechanism (partials and no partial)
            lookup_proc = lambda { |partial| @_scope.find_template(file, [], partial) }
            template = lookup_proc.call(false) rescue lookup_proc.call(true)
            file_path = File.join(Rails.root.to_s, template.inspect) if template
          else # fallback to manual
            root_path = Rails.root
            view_path = options[:view_path] || File.join(root_path, "app/views/")
            file_path = Dir[File.join(view_path, file + ".{*.,}rabl")].first
          end
        elsif defined? Sinatra
          view_path = options[:view_path] || @_scope.settings.views
          file_path = Dir[File.join(view_path, file + ".{*.,}rabl")].first
        end

        [File.read(file_path.to_s), file_path.to_s] if file_path
      end
    end

  end # Partials
end # Rabl