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
        file_path = if defined? Padrino
          fetch_padrino_source(file, options)
        elsif defined?(Rails) && context_scope
          fetch_rails_source(file, options)
        elsif defined? Sinatra
          fetch_sinatra_source(file, options)
        end

        raise "Cannot find rabl template '#{file}' within registered view paths!" unless File.exist?(file_path.to_s)
        [File.read(file_path.to_s), file_path.to_s] if file_path
      end
    end

    private

    # Returns the rabl template path for padrino views using configured views
    def fetch_padrino_source(file, options={})
      view_path = Array(options[:view_path] || context_scope.settings.views)
      # use Padrino's own template resolution mechanism
      file_path, _ = context_scope.instance_eval { resolve_template(file) }
      # Padrino chops the extension, stitch it back on
      File.join(view_path.first.to_s, (file_path.to_s + ".rabl"))
    end

    # Returns the rabl template path for Rails, including special lookups for Rails 2 and 3
    def fetch_rails_source(file, options={})
      # use Rails template resolution mechanism if possible (find_template)
      source_format = request_format if defined?(request_format)
      view_path = Array(options[:view_path] || context_scope.view_paths.to_a)
      if source_format && context_scope.respond_to?(:lookup_context) # Rails 3
        lookup_proc = lambda { |partial| context_scope.lookup_context.find_template(file, [], partial) }
        template = lookup_proc.call(false) rescue lookup_proc.call(true)
        template.identifier if template
      elsif source_format && context_scope.respond_to?(:view_paths) # Rails 2
        template = context_scope.view_paths.find_template(file, source_format, false)
        template.filename if template
      else # manual file lookup
        fetch_manual_template(view_path, file)
      end
    end

    # Returns the rabl template path for sinatra views using configured views
    def fetch_sinatra_source(file, options={})
      view_path = Array(options[:view_path] || context_scope.settings.views)
      fetch_manual_template(view_path, file)
    end

    # Returns the rabl template by looking up files within the view_path and specified file path
    def fetch_manual_template(view_path, file)
      Dir[File.join("{#{view_path.join(",")}}", "{#{file},#{partialized(file)}}" + ".{*.,}rabl")].first
    end

    # Returns a partialized version of a file path
    # partialized("v1/variants/variant") => "v1/variants/_variant"
    def partialized(file)
      partial_file = file.split(File::SEPARATOR)
      partial_file[-1] = "_#{partial_file[-1]}" unless partial_file[-1].start_with?("_")
      partial_file.join(File::SEPARATOR)
    end

  end # Partials
end # Rabl
