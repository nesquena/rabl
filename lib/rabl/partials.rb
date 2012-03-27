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
      engine_options = options.reverse_merge(:format => "hash", :root => (options[:root] || false))
      Rabl::Engine.new(options[:source], engine_options).render(@_scope, :object => object, &block)
    end

    # Returns source for a given relative file
    # fetch_source("show", :view_path => "...") => "...contents..."
    def fetch_source(file, options={})
      Rabl.source_cache(file, options[:view_path]) do
        if defined? Padrino
          view_path = Array(options[:view_path] || context_scope.settings.views)
          # use Padrino's own template resolution mechanism
          file_path, _ = context_scope.instance_eval { resolve_template(file) }
          # Padrino chops the extension, stitch it back on
          file_path = File.join(view_path.first.to_s, (file_path.to_s + ".rabl"))
        elsif defined?(Rails) && context_scope
          # use Rails template resolution mechanism if possible (find_template)
          source_format = request_format if defined?(request_format)
          view_path = Array(options[:view_path] || context_scope.view_paths.to_a)
          if source_format && context_scope.respond_to?(:lookup_context) # Rails 3
            lookup_proc = lambda { |partial| context_scope.lookup_context.find_template(file, [], partial) }
            template = lookup_proc.call(false) rescue lookup_proc.call(true)
            file_path = template.identifier if template
          elsif source_format && context_scope.respond_to?(:view_paths) # Rails 2
            template = context_scope.view_paths.find_template(file, source_format, false)
            file_path = template.filename if template
          else # fallback to manual
            file_path = Dir[File.join("{#{view_path.join(",")}}", file + ".{*.,}rabl")].first
          end
        elsif defined? Sinatra
          view_path = Array(options[:view_path] || context_scope.settings.views)
          file_path = Dir[File.join("{#{view_path.join(",")}}", file + ".{*.,}rabl")].first
        end

        raise "Cannot find rabl template '#{file}' within registered views!" unless File.exist?(file_path.to_s)
        [File.read(file_path.to_s), file_path.to_s] if file_path
      end
    end

  end # Partials
end # Rabl