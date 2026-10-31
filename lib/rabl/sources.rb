# frozen_string_literal: true

module Rabl
  module Sources
    include Helpers

    # Each distinct view path list or set of lookup details => the number standing for it in
    # source cache keys, so a key is quick to compare however many view paths there are.
    # The numbers come from its size, so it must never be cleared without LOOKUP_IDS_BY_OBJECT.
    LOOKUP_IDS = {}
    LOOKUP_IDS_LOCK = Mutex.new
    # Rails' frozen view path lists and details keys => their numbers, worked out once per object.
    # ceiling: CRuby 3.2 and higher only (JRuby's WeakMap holds its keys strongly, and before 3.2
    # CRuby's slows its GC down with many dead keys); elsewhere the numbers are worked out on
    # each lookup. Upgrade path: enable it on an engine once its WeakMap holds keys weakly
    # without that cost.
    LOOKUP_IDS_BY_OBJECT = (ObjectSpace::WeakMap.new if RUBY_ENGINE == "ruby" && RUBY_VERSION >= "3.2")

    # Returns source for a given relative file
    # fetch_source("show", :view_path => "...") => "...contents..."
    def fetch_source(file, options = {})
      resolver = source_resolver
      lookup = source_lookup(resolver) if Rabl.configuration.cache_sources
      # a lookup that can't be told apart from others (see source_lookup) isn't cached
      return resolve_source(file, options, resolver) if lookup == false

      Rabl.source_cache(file, Array(options[:view_path]), lookup) do
        resolve_source(file, options, resolver)
      end
    end

    private
      # Looks the file up with the given resolver and returns its source and path
      def resolve_source(file, options, resolver)
        view_paths = Array(options[:view_path]) + Array(Rabl.configuration.view_paths)

        file_path = \
          case resolver
          when :padrino
            fetch_padrino_source(file, options)
          when :rails
            _view_paths = view_paths + Array(context_scope.view_paths.to_a)
            fetch_rails_source(file, options) || fetch_manual_template(_view_paths, file, rails_lookup_format, rails_lookup_locales)
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
      # details such as versioncake's versions) and the view paths; elsewhere the format
      # and locales the manual lookup prefers, and under Sinatra the app's views. Returns
      # false when a view path has no stable name, so the lookup isn't cached.
      def source_lookup(resolver)
        case resolver
        when :rails
          view_paths = rails_view_paths_id or return false
          details = rails_details_id
          return false if details == false
          [rails_lookup_format, details, view_paths]
        when :sinatra
          [context_scope.settings.views, manual_source_format, manual_source_locales]
        else
          [manual_source_format, manual_source_locales]
        end
      end

      # Returns the number standing for the Rails view paths, the same for the same paths,
      # or false when one of them has no stable name (a resolver without to_path)
      def rails_view_paths_id
        paths = context_scope.view_paths
        paths = paths.respond_to?(:paths) ? paths.paths : Array(paths.to_a)
        # Rails 7.1 and higher freeze a PathSet's paths
        lookup_id_by_object(paths.frozen? && paths) do
          names = paths.map do |path|
            if path.is_a?(String)
              path
            elsif path.respond_to?(:to_path)
              path.to_path.to_s
            else
              break
            end
          end
          names ? lookup_id([:view_paths, names]) : false # false is remembered too
        end
      end

      # Returns the number standing for the Rails lookup context's details
      def rails_details_id
        lookup_context = context_scope.lookup_context if context_scope.respond_to?(:lookup_context)
        return unless lookup_context
        # Rails reads the registered details from ActionView::LookupContext itself (7.0 and higher keep
        # them there only, so a subclass's own are nil). Module#=== checks the object itself, not what
        # a delegator forwards to.
        names = ActionView::LookupContext.registered_details if defined?(ActionView::LookupContext) && ActionView::LookupContext === lookup_context
        names ||= lookup_context.class.registered_details if lookup_context.class.respond_to?(:registered_details)
        return false unless names # what the lookup depends on can't be told, so it isn't cached

        # Rails' details_key is the same object for the same details until Rails clears them
        # (in development, when templates change), and the details give the same number again then
        details_key = lookup_context.details_key if lookup_context.respond_to?(:details_key)
        lookup_id_by_object(details_key) do
          # Rails' own accessors: LookupContext#locale returns the first locale, the lookup
          # uses the whole chain (I18n.locale, its fallbacks and the default locale)
          accessors = ActionView::LookupContext::Accessors if defined?(ActionView::LookupContext::Accessors)
          details = names.map do |name|
            if accessors && accessors === lookup_context && accessors.method_defined?(name)
              accessors.instance_method(name).bind_call(lookup_context)
            else
              lookup_context.public_send(name)
            end
          end
          lookup_id([:details, details])
        end
      end

      # Returns the number for object, or the block's number, which it is then kept for
      def lookup_id_by_object(object)
        return yield unless object && LOOKUP_IDS_BY_OBJECT

        id = LOOKUP_IDS_BY_OBJECT[object]
        id.nil? ? (LOOKUP_IDS_BY_OBJECT[object] = yield) : id
      end

      # Returns the number standing for value, the same for an equal value
      def lookup_id(value)
        LOOKUP_IDS[value] || LOOKUP_IDS_LOCK.synchronize do
          LOOKUP_IDS.fetch(value) { LOOKUP_IDS[Rabl.frozen_copy(value)] = LOOKUP_IDS.size }
        end
      end

      # Returns the format Rails 3.2 and higher look templates up in:
      # the request's format, or request_format for HTML requests (as a Symbol,
      # the only form Rails 7.0 and higher match)
      def rails_source_format
        format = context_scope.request.format.to_sym
        format == :html ? request_format.to_sym : format
      end

      # Returns the format Rails looks the template up in or, when there is none (a view
      # without a request, or a request format Rails doesn't know, where that lookup fails
      # and the manual lookup is used), the format being rendered
      def rails_lookup_format
        rails_source_format || manual_source_format
      rescue StandardError
        manual_source_format
      end

      # Returns the locale chain of the Rails lookup context, which the source cache key holds
      # (it can differ from I18n's, e.g. in I18n.with_locale or outside a controller action),
      # or I18n's chain when the lookup context isn't Rails' own
      def rails_lookup_locales
        lookup_context = context_scope.lookup_context if context_scope.respond_to?(:lookup_context)
        accessors = ActionView::LookupContext::Accessors if defined?(ActionView::LookupContext::Accessors)
        # Module#=== checks the object itself, not what a delegator forwards to (see rails_details_id)
        return manual_source_locales unless lookup_context && accessors && accessors === lookup_context && accessors.method_defined?(:locale)

        Array(accessors.instance_method(:locale).bind_call(lookup_context)).map(&:to_s)
      end

      # Returns the format the manual lookup prefers: the format being rendered (json for hash),
      # which nested templates are given as :source_format
      def manual_source_format
        # Engine keeps its options in @_options, Builder in @options
        options = (@_options if defined?(@_options)) || (@options if defined?(@options))
        format = options[:source_format] || options[:format] if options
        format ||= request_format if defined?(request_format)
        format = format.to_s
        format.empty? || format == "hash" ? "json" : format
      end

      # Returns the locales the manual lookup prefers, best first: like Rails' lookup,
      # I18n's locale, its fallbacks and the default locale
      def manual_source_locales
        return [] unless defined?(::I18n) && ::I18n.respond_to?(:locale)

        locales = [::I18n.locale]
        locales.concat(::I18n.fallbacks[::I18n.locale]) if ::I18n.respond_to?(:fallbacks)
        locales << ::I18n.default_locale
        locales.uniq.map(&:to_s)
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

      # Returns the rabl template by looking up files within the view_path and specified file path.
      # Like Rails' lookup, it takes a template named for the format and locales it is given
      # ("show.json.rabl", "show.fr.json.rabl", "show.fr.rabl" or "show.rabl"), the best named
      # in the first view path, and the file before the partial, that has one; otherwise the
      # first file found ("show.xml.rabl" for json), as it always has.
      # ceiling: other details in a name, such as variants ("show.json+mobile.rabl"), never match
      # here; Rails' own lookup handles those where it is used.
      def fetch_manual_template(view_path, file, format = manual_source_format, locales = manual_source_locales)
        found = Dir[File.join("{#{view_path.join(",")}}", "{#{file},#{partialized(file)}}" + ".{*.,}rabl")]
        names = [File.basename(file), File.basename(partialized(file))]
        best = best_rank = best_group = nil

        # Dir returns the files of each view path and name together, in the order given
        found.each do |path|
          dir, base = File.split(path)
          name = names.find { |n| base.start_with?("#{n}.") } or next
          group = [dir, name]
          break if best && group != best_group

          rank = manual_template_rank(base[(name.size + 1)...-4].split("."), format.to_s, locales)
          best, best_rank, best_group = path, rank, group if rank && (!best || (rank <=> best_rank) < 0)
        end

        best || found.first
      end

      # Ranks the details in a template's name ("fr.json" => ["fr", "json"]) the way Rails
      # sorts them, the locale first: a smaller rank is better, nil means they don't match
      def manual_template_rank(details, format, locales)
        format_rank = details.last == format ? 1 : 2
        details = details[0...-1] if format_rank == 1
        return [locales.size, format_rank] if details.empty?

        locale_rank = locales.index(details.first)
        [locale_rank, format_rank] if locale_rank && details.size == 1
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
