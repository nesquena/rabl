require 'tmpdir'
require 'pathname'
require File.expand_path('../teststrap', __FILE__)

class TestPartial
  include Rabl::Partials
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
end # Rabl::Partials
