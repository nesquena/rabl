module Rabl
  module Partials
    include Rabl::Helpers

    # Renders a partial hash based on another rabl template
    # partial("users/show", :object => @user)
    # options must have :object
    # options can have :view_path, :child_root, :root
    def partial(file, options={}, &block)
      raise ArgumentError, "Must provide an :object option to render a partial" unless options.has_key?(:object)
      object, view_path = options.delete(:object), options[:view_path] || @_view_path
      source, location = self.fetch_source(file, :view_path => view_path)
      engine_options = options.merge(:source => source, :source_location => location, :template => file)
      self.object_to_hash(object, engine_options, &block)
    end

    # Returns a hash based representation of any data object given ejs template block
    # object_to_hash(@user) { attribute :full_name } => { ... }
    # object_to_hash(@user, :source => "...") { attribute :full_name } => { ... }
    # object_to_hash([@user], :source => "...") { attribute :full_name } => { ... }
    # options must have :source (rabl file contents)
    # options can have :source_location (source filename)
    def object_to_hash(object, options={}, &block)
      return object if object.nil?
      return [] if is_collection?(object) && object.blank? # empty collection
      engine_options = options.reverse_merge(:format => "hash", :view_path => @_view_path, :root => (options[:root] || false))
      Rabl::Engine.new(options[:source], engine_options).render(@_scope, :object => object, :locals => options[:locals], &block)
    end

    # Returns source for a given relative file
    # fetch_source("show", :view_path => "...") => "...contents..."
    def fetch_source(file, options={})
      view_paths = Array(options[:view_path]) + Array(Rabl.configuration.view_paths)
      Rabl.source_cache(file, view_paths) do
        file_path = if defined?(Padrino) && context_scope.respond_to?(:settings) && context_scope.respond_to?(:resolve_template)
          fetch_padrino_source(file, options)
        elsif defined?(Rails) && context_scope.respond_to?(:view_paths)
          _view_paths = view_paths + Array(context_scope.view_paths.to_a)
          fetch_rails_source(file, options) || fetch_manual_template(_view_paths, file)
        elsif defined?(Sinatra) && context_scope.respond_to?(:settings)
          fetch_sinatra_source(file, options)
        else # generic template resolution
          fetch_manual_template(view_paths, file)
        end

        unless File.exist?(file_path.to_s)
          raise "Cannot find rabl template '#{file}' within registered (#{view_paths.map(&:to_s).inspect}) view paths!"
        end

        [File.read(file_path.to_s), file_path.to_s]
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
      if source_format && context_scope.respond_to?(:lookup_context) # Rails 3
        lookup_proc = lambda { |partial|
          if ActionPack::VERSION::MAJOR == 3 && ActionPack::VERSION::MINOR < 2
            context_scope.lookup_context.find(file, [], partial)
          else # Rails 3.2 and higher
            # pull format directly from rails unless it is html
            rendered_format = context_scope.lookup_context.rendered_format
            source_format = rendered_format unless rendered_format == :html
            context_scope.lookup_context.find(file, [], partial, [], {:formats => [source_format]})
          end }
        template = lookup_proc.call(false) rescue nil
        template ||= lookup_proc.call(true) rescue nil
        template.identifier if template
      elsif source_format && context_scope.respond_to?(:view_paths) # Rails 2
        template = context_scope.view_paths.find_template(file, source_format, false)
        template.filename if template
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
