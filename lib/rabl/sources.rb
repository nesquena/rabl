# frozen_string_literal: true

module Rabl
  module Sources
    include Helpers

    # Returns source for a given relative file
    # fetch_source("show", :view_path => "...") => "...contents..."
    def fetch_source(file, options = {})
      custom_view_path = Array(options[:view_path])
      resolver = source_resolver
      lookup = source_lookup(resolver) if Rabl.configuration.cache_sources

      Rabl.source_cache(file, custom_view_path, lookup) do
        view_paths = custom_view_path + Array(Rabl.configuration.view_paths)

        file_path = \
          case resolver
          when :padrino
            fetch_padrino_source(file, options)
          when :rails
            _view_paths = view_paths + Array(context_scope.view_paths.to_a)
            fetch_rails_source(file, options) || fetch_manual_template(_view_paths, file)
          when :sinatra
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
      # Returns which framework's template lookup fetch_source uses in this context_scope
      def source_resolver
        if defined?(Padrino) && context_scope.respond_to?(:settings) && context_scope.respond_to?(:resolve_template)
          :padrino
        elsif defined?(Rails) && context_scope.respond_to?(:view_paths)
          :rails
        elsif defined?(Sinatra) && context_scope.respond_to?(:settings) && context_scope.settings.respond_to?(:views)
          :sinatra
        end
      end

      # Returns what, besides the file and the :view_path option, the resolver's lookup
      # depends on, so the source cache keeps each lookup's result apart: under Rails the
      # format, the lookup details (formats, locale, variants, handlers, and registered
      # details such as versioncake's versions) and the view paths; under Sinatra the app's views.
      def source_lookup(resolver)
        case resolver
        when :rails
          lookup_context = context_scope.lookup_context if context_scope.respond_to?(:lookup_context)
          # Rails' own key for the details, the same object for the same details
          details = lookup_context.details_key if lookup_context.respond_to?(:details_key)
          if details.nil? && lookup_context.class.respond_to?(:registered_details)
            details = lookup_context.class.registered_details.map { |name| lookup_context.public_send(name) }
          end
          format = begin
            rails_source_format if defined?(request_format)
          rescue StandardError
            nil # fetch_rails_source's lookup fails the same way and falls back to the manual lookup
          end
          [format, details, context_scope.view_paths.map(&:to_s)]
        when :sinatra
          context_scope.settings.views
        end
      end

      # Returns the format Rails 3.2 and higher look templates up in:
      # the request's format, or request_format for HTML requests
      def rails_source_format
        format = context_scope.request.format.to_sym
        format == :html ? request_format : format
      end

      # Returns the rabl template path for padrino views using configured views
      def fetch_padrino_source(file, options = {})
        view_path = Array(options[:view_path] || context_scope.settings.views)

        # use Padrino's own template resolution mechanism
        file_path, _ = context_scope.instance_eval { resolve_template(file) }

        # Padrino chops the extension, stitch it back on
        File.join(view_path.first.to_s, (file_path.to_s + ".rabl"))
      end

      # Returns the rabl template path for Rails, including special lookups for Rails 2 and 3
      def fetch_rails_source(file, options = {})
        # use Rails template resolution mechanism if possible (find_template)
        source_format = request_format if defined?(request_format)

        if source_format && context_scope.respond_to?(:lookup_context) # Rails 3
          lookup_proc = lambda do |partial|
            if ActionPack::VERSION::MAJOR == 3 && ActionPack::VERSION::MINOR < 2
              context_scope.lookup_context.find(file, [], partial)
            else # Rails 3.2 and higher
              # pull format directly from rails unless it is html
              context_scope.lookup_context.find(file, [], partial, [], { :formats => [rails_source_format] })
            end
          end
          template = lookup_proc.call(false) rescue nil
          template ||= lookup_proc.call(true) rescue nil
          template.identifier if template
        elsif source_format && context_scope.respond_to?(:view_paths) # Rails 2
          template = context_scope.view_paths.find_template(file, source_format, false)
          template.filename if template
        end
      end

      # Returns the rabl template path for sinatra views using configured views
      def fetch_sinatra_source(file, options = {})
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
