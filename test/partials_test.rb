# frozen_string_literal: true

require 'tmpdir'
require 'delegate'
require 'pathname'
require File.expand_path('../teststrap', __FILE__)

class TestPartial
  include Rabl::Partials
end

# A view path resolver, like a custom ActionView::Resolver: it has no name but its object
class TestResolver
  attr_reader :dir
  def initialize(dir); @dir = dir; end
end

# A resolver named by its path, like ActionView::FileSystemResolver
class TestPathResolver < TestResolver
  attr_reader :named
  def to_path; @named = named.to_i + 1; dir; end
end

# A list of view paths that keeps them frozen, like a PathSet on Rails 7.1 and higher
class TestPathSet
  attr_reader :paths
  def initialize(paths); @paths = paths.freeze; end
  def to_a; paths.dup; end
end

# Looks templates up the way ActionView's lookup context does: by name and the
# requested format, locale chain and variant ("test.fr.json+mobile.rabl")
class TestLookupContext
  # Like Rails' generated accessors, these return the whole detail
  module Accessors
    def locale; @locale; end
  end
  include Accessors

  # Like Rails 7.0 and higher, on this class only (a subclass's are nil)
  singleton_class.send(:attr_accessor, :registered_details)
  self.registered_details = [:locale, :formats, :variants]

  attr_accessor :formats, :variants, :details_key, :lookups

  def initialize(view_path, details = {})
    @view_path, @lookups = view_path, 0
    @locale, @formats, @variants = Array(details[:locale] || :en), details[:formats] || [:json], details[:variants] || []
  end

  # Like Rails, the first locale of the chain the lookup uses
  def locale
    @locale.first
  end

  def find(name, prefixes = [], partial = false, keys = [], options = {})
    @lookups += 1
    locales = @locale.map { |l| ".#{l}" } + [""]
    variants = (self.variants.map { |v| "+#{v}" }) + [""]
    format = (options[:formats] || formats).first
    # like Rails 7.0 and higher, which match formats given as Symbols only
    raise "Missing template #{name}" unless format.is_a?(Symbol)
    candidates = locales.product(variants).map { |l, v| File.join(@view_path, "#{name}#{l}.#{format}#{v}.rabl") }
    path = candidates.find { |candidate| File.exist?(candidate) } or raise "Missing template #{name}"
    Struct.new(:identifier).new(path)
  end
end

context "Rabl::Partials" do
  context "fetch_source with json" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

    setup do
      ::Sinatra = stub(Class.new)
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts "content"
      end
      File.open(tmp_path + "test_v1.json.rabl", "w") do |f|
        f.puts "content_v1"
      end
      FileUtils.touch tmp_path + "test_v2.json.rabl"
      [TestPartial.new.fetch_source('test', :view_path => tmp_path.to_s),
       TestPartial.new.fetch_source('test_v1', :view_path => tmp_path.to_s)]
    end

    asserts(:first).equals {["content\n", (tmp_path + "test.json.rabl").to_s ]}
    asserts(:last).equals {["content_v1\n", (tmp_path + "test_v1.json.rabl").to_s ]}
    teardown { Object.send(:remove_const, :Sinatra) }
  end

  context "fetch_source with rabl" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

    setup do
      ::Sinatra = stub(Class.new)
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts "content"
      end
      TestPartial.new.fetch_source('test', :view_path => tmp_path.to_s)
    end
    asserts('detects file.rabl') { topic }.equals do
      ["content\n", (tmp_path + 'test.rabl').to_s]
    end
    teardown { Object.send(:remove_const, :Sinatra) }
  end

  context "fetch_source with view_path" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

    setup do
      ::Sinatra = stub(Class.new)
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts "content"
      end
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts "content2"
      end
      TestPartial.new.fetch_source('test', :view_path => tmp_path.to_s)
    end
    asserts('detects file.json.rabl first') { topic }.equals do
      ["content2\n", (tmp_path + 'test.json.rabl').to_s]
    end
    teardown { Object.send(:remove_const, :Sinatra) }
  end

  context "fetch source using configured view paths" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

    setup do
      Rabl.configure do |config|
        config.view_paths = tmp_path
      end

      ::Sinatra = stub(Class.new)
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts "content"
      end
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts "content2"
      end
      TestPartial.new.fetch_source('test')
    end
    asserts('detects file.json.rabl first') { topic }.equals do
      ["content2\n", (tmp_path + 'test.json.rabl').to_s]
    end
    teardown do
      Object.send(:remove_const, :Sinatra)
      Rabl.configuration.view_paths = []
    end
  end

  context "partial_as_engine using configured view paths" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

    setup do
      File.open(tmp_path + "_test.rabl", "w")
      Rabl::Engine.new('', :view_path => tmp_path)
    end

    asserts('returns new engine with given view_path') do
      topic.partial_as_engine('test', :object => {}).view_path
    end.equals do
      tmp_path
    end

    teardown do
      Rabl.configuration.view_paths = []
    end
  end


  context "fetch source with custom scope" do
    context "when Padrino is defined" do
      helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

      setup do
        ::Padrino = stub(Class.new)
        Rabl.configuration.cache_sources = false
        @it = TestPartial.new

        def @it.context_scope; @context_scope ||= Object.new; end
        context_scope = @it.context_scope
        def context_scope.settings; end

        File.open(tmp_path + "test.json.rabl", "w") { |f| f.puts "content" }
      end

      asserts('Padrino constant dont break manual lookup') do
        @it.fetch_source('test', :view_path => tmp_path.to_s)
      end.equals do
        ["content\n", (tmp_path + "test.json.rabl").to_s ]
      end

      teardown { Object.send(:remove_const, :Padrino) }
    end

    context "when Sinatra is defined" do
      helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

      setup do
        ::Sinatra = stub(Class.new)
        Rabl.configuration.cache_sources = false
        @it = TestPartial.new

        def @it.context_scope; @context_scope ||= Object.new; end
        context_scope = @it.context_scope
        def context_scope.settings; @settings ||= Object.new end

        File.open(tmp_path + "test.json.rabl", "w") { |f| f.puts "content" }
      end

      asserts('Sinatra constant dont break manual lookup') do
        @it.fetch_source((tmp_path + "test").to_s)
      end.equals do
        ["content\n", "/" + (tmp_path + "test.json.rabl").to_s ]
      end

      teardown { Object.send(:remove_const, :Sinatra) }
    end
  end

  context "fetch source with Rails" do
    context "and :view_path" do
      helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

      setup do
        ::Rails = stub(Class.new)
        ::ActionPack = Module.new
        ::ActionPack::VERSION = Module.new
        ::ActionPack::VERSION::MAJOR = 3
        ::ActionPack::VERSION::MINOR = 2
        @it = TestPartial.new

        def @it.context_scope; @context_scope ||= Object.new; end
        def @it.request_format; :json; end
        context_scope = @it.context_scope

        def context_scope.view_paths; []; end
        def context_scope.lookup_context; @lookup_context ||= Object.new; end
        lookup_context = context_scope.lookup_context

        def lookup_context.rendered_format; :json; end
        def lookup_context.find(*args)
          raise RuntimeError, 'Something happen with Rails lookup'
        end

        File.open(tmp_path + "test.json.rabl", "w") { |f| f.puts "content" }

        @it
      end

      asserts('rails lookups dont break manual') do
        @it.fetch_source('test', :view_path => tmp_path.to_s)
      end.equals do
        ["content\n", (tmp_path + "test.json.rabl").to_s ]
      end

      teardown do
        Object.send(:remove_const, :Rails)
        Object.send(:remove_const, :ActionPack)
        Rabl.configuration.view_paths = []
      end
    end
  end # Rails

  context "fetch_source with cache_sources" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }
    helper(:write) { |name, content| File.open(tmp_path + name, "w") { |f| f.puts content } }

    # A Rails view for a request in the given format with the given lookup details
    helper(:rails_partial) do |format, details = {}, view_paths = []|
      partial = TestPartial.new
      scope = Object.new
      view_path = (view_paths.respond_to?(:paths) ? view_paths.paths : view_paths).first || tmp_path
      lookup_context = TestLookupContext.new((view_path.respond_to?(:dir) ? view_path.dir : view_path).to_s, details)
      request = Struct.new(:format).new(Struct.new(:to_sym).new(format))
      scope.define_singleton_method(:lookup_context) { lookup_context }
      scope.define_singleton_method(:view_paths) { view_paths }
      scope.define_singleton_method(:request) { request }
      partial.define_singleton_method(:context_scope) { scope }
      partial.define_singleton_method(:request_format) { format.to_s }
      partial
    end

    teardown do
      Rabl.configuration.cache_sources = false
      Rabl.reset_source_cache!
    end

    context "under Rails" do
      setup do
        ::Rails = stub(Class.new)
        ::ActionPack = Module.new
        ::ActionPack::VERSION = Module.new
        ::ActionPack::VERSION::MAJOR = 8
        ::ActionPack::VERSION::MINOR = 1
        ::ActionView = Module.new
        ::ActionView::LookupContext = TestLookupContext
        Rabl.configuration.cache_sources = true

        write "test.json.rabl", "json"
        write "test.json+mobile.rabl", "json mobile"
        write "test.xml.rabl", "xml"
        write "test.fr.json.rabl", "json fr"
      end

      asserts("a variant gets its own template after the plain one is cached") do
        Rabl.reset_source_cache!
        [rails_partial(:json).fetch_source("test")[0], rails_partial(:json, :variants => [:mobile]).fetch_source("test")[0]]
      end.equals ["json\n", "json mobile\n"]

      asserts("the plain template after a variant is cached") do
        Rabl.reset_source_cache!
        [rails_partial(:json, :variants => [:mobile]).fetch_source("test")[0], rails_partial(:json).fetch_source("test")[0]]
      end.equals ["json mobile\n", "json\n"]

      asserts("each format gets its own template") do
        Rabl.reset_source_cache!
        [rails_partial(:json).fetch_source("test")[0], rails_partial(:xml).fetch_source("test")[0]]
      end.equals ["json\n", "xml\n"]

      asserts("each locale gets its own template") do
        Rabl.reset_source_cache!
        [rails_partial(:json).fetch_source("test")[0], rails_partial(:json, :locale => :fr).fetch_source("test")[0]]
      end.equals ["json\n", "json fr\n"]

      asserts("each locale chain gets its own template, for the same first locale") do
        Rabl.reset_source_cache!
        [rails_partial(:json, :locale => [:de, :fr]).fetch_source("test")[0], rails_partial(:json, :locale => [:de, :en]).fetch_source("test")[0]]
      end.equals ["json fr\n", "json\n"]

      asserts("a lookup context that isn't Rails' own is read through its own methods") do
        Rabl.reset_source_cache!
        duck = Class.new do
          define_singleton_method(:registered_details) { TestLookupContext.registered_details }
          define_method(:initialize) { |context| @context = context }
          [:formats, :variants, :find].each { |name| define_method(name) { |*args| @context.public_send(name, *args) } }
          define_method(:locale) { [@context.locale] }
        end
        [:fr, :en].map do |locale|
          partial = rails_partial(:json, :locale => locale)
          context = duck.new(partial.context_scope.lookup_context)
          partial.context_scope.singleton_class.send(:remove_method, :lookup_context)
          partial.context_scope.define_singleton_method(:lookup_context) { context }
          partial.fetch_source("test")[0]
        end
      end.equals ["json fr\n", "json\n"]

      asserts("a subclass of the lookup context gets its own template per locale") do
        Rabl.reset_source_cache!
        subclass = Class.new(TestLookupContext)
        [:fr, :en].map do |locale|
          partial = rails_partial(:json, :locale => locale)
          context = subclass.new(tmp_path.to_s, :locale => locale)
          partial.context_scope.singleton_class.send(:remove_method, :lookup_context)
          partial.context_scope.define_singleton_method(:lookup_context) { context }
          partial.fetch_source("test")[0]
        end
      end.equals ["json fr\n", "json\n"]

      asserts("a lookup context whose details can't be listed is looked up each time") do
        Rabl.reset_source_cache!
        sources = [:fr, :en].map do |locale|
          partial = rails_partial(:json, :locale => locale)
          context = SimpleDelegator.new(partial.context_scope.lookup_context)
          partial.context_scope.singleton_class.send(:remove_method, :lookup_context)
          partial.context_scope.define_singleton_method(:lookup_context) { context }
          partial.fetch_source("test")[0]
        end
        [sources, Rabl.instance_variable_get(:@_source_cache).size]
      end.equals [["json fr\n", "json\n"], 0]

      asserts("each set of view paths gets its own template") do
        Rabl.reset_source_cache!
        other_path = Pathname.new(Dir.mktmpdir)
        File.open(other_path + "other.json.rabl", "w") { |f| f.puts "other" }
        write "other.json.rabl", "default"
        [rails_partial(:json, {}, [tmp_path.to_s]).fetch_source("other")[0], rails_partial(:json, {}, [other_path.to_s]).fetch_source("other")[0]]
      end.equals ["default\n", "other\n"]

      asserts("a resolver without a name is looked up each time, without growing the cache") do
        Rabl.reset_source_cache!
        other_path = Pathname.new(Dir.mktmpdir)
        File.open(other_path + "other.json.rabl", "w") { |f| f.puts "other" }
        write "other.json.rabl", "default"
        sources = [tmp_path, other_path, tmp_path, other_path].map do |path|
          rails_partial(:json, {}, [TestResolver.new(path.to_s)]).fetch_source("other")[0]
        end
        [sources, Rabl.instance_variable_get(:@_source_cache).size]
      end.equals [["default\n", "other\n", "default\n", "other\n"], 0]

      asserts("resolvers with the same path share their cache entry") do
        Rabl.reset_source_cache!
        partials = Array.new(2) { rails_partial(:json, {}, [TestPathResolver.new(tmp_path.to_s)]) }
        partials.each { |partial| partial.fetch_source("test") }
        partials.map { |partial| partial.context_scope.lookup_context.lookups }
      end.equals [1, 0]

      asserts("details keys for the same details share their cache entry") do
        Rabl.reset_source_cache!
        # a new details key for the same details, as after Rails clears its details keys
        partials = Array.new(2) { rails_partial(:json, :variants => [:mobile]) }
        partials.each { |partial| partial.context_scope.lookup_context.details_key = Object.new }
        partials.each { |partial| partial.fetch_source("test") }
        partials.map { |partial| partial.context_scope.lookup_context.lookups }
      end.equals [1, 0]

      asserts("frozen lists of view paths are named once each, and apart") do
        Rabl.reset_source_cache!
        other_path = Pathname.new(Dir.mktmpdir)
        File.open(other_path + "other.json.rabl", "w") { |f| f.puts "other" }
        write "other.json.rabl", "default"
        resolvers = [TestPathResolver.new(tmp_path.to_s), TestPathResolver.new(other_path.to_s)]
        path_sets = resolvers.map { |resolver| TestPathSet.new([resolver]) }
        sources = [0, 1, 0, 1].map { |i| rails_partial(:json, {}, path_sets[i]).fetch_source("other")[0] }
        # named once per list where the memo exists (CRuby 3.2 and higher), on each lookup elsewhere
        [sources, resolvers.map(&:named)]
      end.equals do
        named = defined?(Rabl::Sources::LOOKUP_IDS_BY_OBJECT) && Rabl::Sources::LOOKUP_IDS_BY_OBJECT ? 1 : 2
        [["default\n", "other\n", "default\n", "other\n"], [named, named]]
      end

      asserts("a repeated lookup is served from the cache") do
        Rabl.reset_source_cache!
        partials = [rails_partial(:json, :variants => [:mobile]), rails_partial(:json, :variants => [:mobile])]
        partials.each { |partial| partial.fetch_source("test") }
        partials.map { |partial| partial.context_scope.lookup_context.lookups }
      end.equals [1, 0]

      asserts("an HTML request looks the template up in the lookup context, in request_format") do
        Rabl.reset_source_cache!
        partial = rails_partial(:html, { :variants => [:mobile] }, [tmp_path.to_s])
        partial.singleton_class.send(:remove_method, :request_format)
        partial.define_singleton_method(:request_format) { "json" } # as Engine#request_format for HTML
        [partial.fetch_source("test")[0], partial.context_scope.lookup_context.lookups]
      end.equals ["json mobile\n", 1]

      asserts("a view without a request falls back to the manual lookup") do
        Rabl.reset_source_cache!
        write "plain.json.rabl", "plain"
        partial = rails_partial(:json, {}, [tmp_path.to_s])
        partial.context_scope.singleton_class.send(:remove_method, :request)
        partial.fetch_source("plain")
      end.equals { ["plain\n", (tmp_path + "plain.json.rabl").to_s] }

      teardown do
        Object.send(:remove_const, :Rails)
        Object.send(:remove_const, :ActionPack)
        Object.send(:remove_const, :ActionView)
      end
    end

    context "under Sinatra" do
      setup do
        ::Sinatra = stub(Class.new)
        Rabl.configuration.cache_sources = true
      end

      asserts("each app gets the template in its own views") do
        Rabl.reset_source_cache!
        %w(main admin).map do |app|
          views = Pathname.new(Dir.mktmpdir)
          File.open(views + "test.json.rabl", "w") { |f| f.puts app }
          partial = TestPartial.new
          scope = Object.new
          settings = Struct.new(:views).new(views.to_s)
          scope.define_singleton_method(:settings) { settings }
          partial.define_singleton_method(:context_scope) { scope }
          partial.fetch_source("test")[0]
        end
      end.equals ["main\n", "admin\n"]

      teardown { Object.send(:remove_const, :Sinatra) }
    end
  end
end # Rabl::Partials
