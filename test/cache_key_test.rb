# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'json'
require 'active_support/core_ext/hash/conversions'
require File.expand_path('../teststrap', __FILE__)

context 'Rabl cache keys' do
  # A cache engine storing values in a hash, with the fetch/write/read_multi interface
  helper(:memory_cache) do
    Class.new do
      attr_reader :store
      def initialize; @store = {}; end
      def fetch(key, options = {}); @store.key?(key) ? @store[key] : (@store[key] = yield); end
      def write(key, value, options = {}); @store[key] = value; end
      def read_multi(*keys)
        keys.pop if keys.last.is_a?(Hash)
        keys.inject({}) { |result, key| result[key] = @store[key] if @store.key?(key); result }
      end
    end.new
  end

  helper(:item) do |id, *owner|
    Class.new do
      attr_accessor :id, :name, :owner, :cache_key
      def initialize(id, owner); @id, @name, @owner, @cache_key = id, "item#{id}", owner, "item/#{id}"; end
    end.new(id, owner.first)
  end

  helper(:render) do |source, object, *options|
    Rabl::Engine.new(source, { :format => 'json' }.merge(options.first || {})).render(Object.new, :object => object)
  end

  setup do
    Rabl.configure do |config|
      config.perform_caching   = true
      config.include_json_root = false
      config.cache_engine      = memory_cache
    end
  end

  asserts('two templates caching the same object render their own output') do
    a = item(1)
    [render("object @item\ncache @item\nattributes :id", a), render("object @item\ncache @item\nattributes :name", a)]
  end.equals ['{"id":1}', '{"name":"item1"}']

  asserts('a template reads its cached output on the next render') do
    a = item(2)
    first = render("object @item\ncache @item\nattributes :id", a)
    a.id = 20
    [first, render("object @item\ncache @item\nattributes :id", a)]
  end.equals ['{"id":2}', '{"id":2}']

  asserts('an object and a collection of that object are cached apart') do
    a = item(3)
    [render("object @item\ncache root_object\nattributes :id", a), render("object @item\ncache root_object\nattributes :id", [a])]
  end.equals ['{"id":3}', '[{"id":3}]']

  asserts('empty collections from different templates are cached apart') do
    [render("collection @items\ncache @items\nattributes :id", []), render("collection @items, :root => :things\ncache @items\nattributes :id", [])]
  end.equals ['[]', '{"things":[]}']

  asserts('two child blocks caching the same object are cached apart') do
    render("object @item\nchild(:owner => :a) { cache root_object; attributes :id }\nchild(:owner => :b) { cache root_object; attributes :name }", item(4, item(5)))
  end.equals '{"a":{"id":5},"b":{"name":"item5"}}'

  asserts('child blocks at the same line of different templates are cached apart') do
    owner = item(6)
    [render("object @item\nchild(:owner => :owner) { cache root_object; attributes :id }", item(7, owner)),
     render("object @item\nchild(:owner => :owner) { cache root_object; attributes :name }", item(8, owner))]
  end.equals ['{"owner":{"id":6}}', '{"owner":{"name":"item6"}}']

  asserts('two child blocks on one line caching the same object are cached apart') do
    render("object @item\nchild(:owner => :a) { cache root_object; attributes :id }; child(:owner => :b) { cache root_object; attributes :name }", item(36, item(37)))
  end.equals '{"a":{"id":37},"b":{"name":"item37"}}'

  asserts('cached child blocks are read on the next render') do
    owner = item(9)
    template = "object @item\nchild(:owner => :owner) { cache root_object; attributes :id }"
    first = render(template, item(10, owner))
    owner.id = 90
    [first, render(template, item(10, owner))]
  end.equals ['{"owner":{"id":9}}', '{"owner":{"id":9}}']

  context 'with cache_all_output' do
    setup do
      Rabl.configuration.cache_all_output = true
      Rabl.configuration.cache_engine = memory_cache
    end

    asserts('two templates rendering the same object render their own output') do
      a = item(11)
      first = [render("object @item\nattributes :id", a), render("object @item\nattributes :name", a)]
      a.id = 110
      first + [render("object @item\nattributes :id", a)]
    end.equals ['{"id":11}', '{"name":"item11"}', '{"id":11}']
  end

  context 'with partials' do
    setup do
      Rabl.configuration.cache_engine = memory_cache
      @dir = Dir.mktmpdir
      File.open(File.join(@dir, 'item_id.rabl'), 'w') { |f| f.write("object @item\ncache root_object\nattributes :id\n") }
      File.open(File.join(@dir, 'item_name.rabl'), 'w') { |f| f.write("object @item\ncache root_object\nattributes :name\n") }
      @dir
    end

    asserts('different partials caching the same objects render their own output') do
      items = [item(12), item(13)]
      [render("collection @items\nextends 'item_id'", items, :view_path => topic),
       render("collection @items\nextends 'item_name'", items, :view_path => topic)]
    end.equals ['[{"id":12},{"id":13}]', '[{"name":"item12"},{"name":"item13"}]']

    asserts('a partial cached in a collection is read on the next render') do
      items = [item(14), item(15)]
      first = render("collection @items\nextends 'item_id'", items, :view_path => topic)
      items.each { |i| i.id += 100 }
      [first, render("collection @items\nextends 'item_id'\nattributes :id => :fresh_id", items, :view_path => topic)]
    end.equals ['[{"id":14},{"id":15}]', '[{"fresh_id":114,"id":14},{"fresh_id":115,"id":15}]']

    asserts('two child blocks on one line of a template file are cached apart') do
      File.open(File.join(topic, 'same_line.rabl'), 'w') do |f|
        f.write("object @item\nchild(:owner => :a) { cache root_object; attributes :name }; child(:owner => :b) { cache root_object; attributes :id }\n")
      end
      Rabl::Renderer.json(item(38, item(39)), 'same_line', :view_path => topic, :scope => Object.new)
    end.equals '{"a":{"name":"item39"},"b":{"id":39}}'

    asserts('a partial is cached once for the templates that extend it') do
      a = item(16)
      first = render("object @item\nextends 'item_id'", a, :view_path => topic)
      a.id = 160
      [first, render("object @item\nextends 'item_id'\nattributes :name", a, :view_path => topic)]
    end.equals ['{"id":16}', '{"name":"item16","id":16}']

    asserts('the items of a collection share the digests of their blocks and partials') do
      Rabl.configuration.cache_engine = memory_cache
      digests = 0
      stub.proxy(Rabl::CacheKey).digest { |digest| digests += 1; digest }
      items = (30..35).map { |id| item(id, item(id + 100)) }
      template = "collection @items\nextends 'item_id'\n" \
        "child(:owner => :a) { cache root_object; attributes :id }\nchild(:owner => :b) { cache root_object; attributes :name }"
      output = render(template, items, :view_path => topic)
      # the template (as the blocks' parent), the two blocks and the partial
      [digests, Rabl.configuration.cache_engine.store.size, JSON.parse(output).first]
    end.equals [4, 18, { "id" => 30, "a" => { "id" => 130 }, "b" => { "name" => "item130" } }]

    teardown { FileUtils.rm_rf(@dir) }
  end

  context 'with the same template source in two view paths' do
    setup do
      Rabl.configuration.cache_engine = memory_cache
      @dirs = [Dir.mktmpdir, Dir.mktmpdir]
      @dirs.each { |dir| File.open(File.join(dir, 'show.rabl'), 'w') { |f| f.write("object @item\ncache @item\nextends 'base'\n") } }
      File.open(File.join(@dirs[0], 'base.rabl'), 'w') { |f| f.write("attributes :id\n") }
      File.open(File.join(@dirs[1], 'base.rabl'), 'w') { |f| f.write("attributes :name\n") }
      @dirs
    end

    asserts('Rabl::Renderer renders each view path\'s partials') do
      a = item(17)
      topic.map { |dir| Rabl::Renderer.json(a, 'show', :view_path => dir, :scope => Object.new) }
    end.equals ['{"id":17}', '{"name":"item17"}']

    asserts('an inline template renders each view path\'s partials') do
      a = item(18)
      topic.map { |dir| render("object @item\ncache @item\nextends 'base'", a, :view_path => dir) }
    end.equals ['{"id":18}', '{"name":"item18"}']

    teardown { @dirs.each { |dir| FileUtils.rm_rf(dir) } }
  end

  context 'with the application in a new directory' do
    setup do
      Rabl.configuration.cache_engine = memory_cache
      @dirs = [File.realpath(Dir.mktmpdir), File.realpath(Dir.mktmpdir)]
      @dirs.each do |dir|
        FileUtils.mkdir_p(File.join(dir, 'views'))
        File.open(File.join(dir, 'views', 'show.rabl'), 'w') { |f| f.write("object @item\ncache @item\nattributes :id\n") }
        File.open(File.join(dir, 'views', 'owner.rabl'), 'w') { |f| f.write("object @item\nchild(:owner => :owner) { cache root_object; attributes :id }\n") }
      end
      @dirs
    end

    helper(:render_in) do |dir, template, object|
      Dir.chdir(dir) { Rabl::Renderer.json(object, template, :view_path => File.join(dir, 'views'), :scope => Object.new) }
    end

    asserts('a template reads entries cached before the move') do
      a = item(19)
      first = render_in(topic[0], 'show', a)
      a.id = 190
      [first, render_in(topic[1], 'show', a)]
    end.equals ['{"id":19}', '{"id":19}']

    asserts('a child block reads entries cached before the move') do
      owner = item(20)
      first = render_in(topic[0], 'owner', item(21, owner))
      owner.id = 200
      [first, render_in(topic[1], 'owner', item(21, owner))]
    end.equals ['{"owner":{"id":20}}', '{"owner":{"id":20}}']

    teardown { @dirs.each { |dir| FileUtils.rm_rf(dir) } }
  end

  context 'with nested renderings' do
    setup do
      Rabl.configuration.cache_engine = memory_cache
      @dir = Dir.mktmpdir
      File.open(File.join(@dir, 'nodes.rabl'), 'w') { |f| f.write("object @item\ncache root_object\nnode(:a) { 1 }\nnode(:b) { 2 }\n") }
      @dir
    end

    asserts('a cached child collection renders each format\'s shape') do
      a = item(22, [item(23)])
      source = "object @item\nattributes :id\nchild(:owner => :owners) { cache 'owners'; attributes :name }"
      Rabl.configuration.cache_engine = memory_cache
      xml = render(source, a, :format => 'xml')
      Rabl.configuration.cache_engine = memory_cache
      [render(source, a), render(source, a, :format => 'xml') == xml]
    end.equals ['{"id":22,"owners":[{"owner":{"name":"item23"}}]}', true]

    asserts('a cached partial renders each extends option') do
      a = item(24)
      [render("object @item\nextends 'nodes'", a, :view_path => topic),
       render("object @item\nextends 'nodes', :except => :b", a, :view_path => topic)]
    end.equals ['{"a":1,"b":2}', '{"a":1}']

    asserts('a cached partial tells :except symbols and strings apart') do
      a = item(26)
      [render("object @item\nextends 'nodes', :except => :b", a, :view_path => topic),
       render("object @item\nextends 'nodes', :except => 'b'", a, :view_path => topic)]
    end.equals ['{"a":1}', '{"a":1,"b":2}']

    asserts('a cached template renders each :except given to the renderer') do
      a = item(27)
      [{}, { :except => :b }].map { |options| Rabl::Renderer.json(a, 'nodes', { :view_path => topic, :scope => Object.new }.merge(options)) }
    end.equals ['{"a":1,"b":2}', '{"a":1}']

    asserts('a cached template is keyed by :root and :child_root given to the renderer') do
      Rabl.configuration.cache_engine = memory_cache
      a = item(28)
      [{}, { :root => false }, { :child_root => false }].each do |options|
        Rabl::Renderer.json(a, 'nodes', { :view_path => topic, :scope => Object.new }.merge(options))
      end
      Rabl.configuration.cache_engine.store.size
    end.equals 3

    teardown { FileUtils.rm_rf(@dir) }
  end

  asserts('a template under a non-ASCII directory renders with a binary working directory') do
    stub(Dir).pwd { "/x/caf\xC3\xA9".dup.force_encoding(Encoding::BINARY) }
    render("object @item\ncache @item\nattributes :id", item(25),
      :source_location => "/x/caf\u00e9/views/show.rabl", :view_path => "/x/caf\u00e9/views")
  end.equals '{"id":25}'

  asserts('Dir.pwd is restored after the stub') { Dir.pwd == Dir.getwd }

  teardown { Rabl.reset_configuration! }
end
