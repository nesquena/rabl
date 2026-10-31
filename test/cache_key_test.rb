# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'json'
require 'active_support/core_ext/hash/conversions'
require File.expand_path('../teststrap', __FILE__)

context 'Rabl cache keys' do
  # A cache engine storing values in a hash, with the fetch/write/read_multi interface; it
  # records each call with the namespace of its key (the key's first segment)
  helper(:memory_cache) do
    Class.new do
      attr_reader :store, :calls
      def initialize; @store = {}; @calls = []; end
      def fetch(key, options = {}); record(:fetch, key); @store.key?(key) ? @store[key] : (@store[key] = yield); end
      def write(key, value, options = {}); record(:write, key); @store[key] = value; end
      def read_multi(*keys)
        keys.pop if keys.last.is_a?(Hash)
        keys.each { |key| record(:read_multi, key) }
        keys.inject({}) { |result, key| result[key] = @store[key] if @store.key?(key); result }
      end
      def record(call, key); @calls << [call, key.split('/').first]; end
    end.new
  end

  # Returns a cache holding the entries of the given one under the "rabl/" namespace that
  # versions before 0.18.0 used for every key, as if one of them had cached the same parts
  helper(:earlier_version_cache) do |cache|
    earlier = memory_cache
    cache.store.each { |key, value| earlier.store["rabl/#{key.split('/', 2).last}"] = value }
    earlier
  end

  # The namespace of the keys this version reads and writes
  helper(:current_namespace) { "rabl-v#{Rabl::CACHE_KEY_VERSION}" }

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

  asserts('an engine rendered again with another object renders that object') do
    engine = Rabl::Engine.new("object @item\ncache @item\nattributes :id", :format => 'json')
    [item(42), item(43)].map { |object| engine.render(Object.new, :object => object) }
  end.equals ['{"id":42}', '{"id":43}']

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

    asserts('a block keyed by its own cache key renders each run') do
      render("object @item\n[:id, :name].each { |f| child(:owner => \"o_\#{f}\") { cache [root_object, f]; attributes f } }", item(44, item(45)))
    end.equals '{"o_id":{"id":45},"o_name":{"name":"item45"}}'

    asserts('two templates rendering the same object render their own output') do
      a = item(11)
      first = [render("object @item\nattributes :id", a), render("object @item\nattributes :name", a)]
      a.id = 110
      first + [render("object @item\nattributes :id", a)]
    end.equals ['{"id":11}', '{"name":"item11"}', '{"id":11}']

    asserts('the output cache key is in the current namespace') do
      Rabl.configuration.cache_engine = memory_cache
      render("object @item\nattributes :id", item(46))
      Rabl.configuration.cache_engine.calls.uniq
    end.equals { [[:fetch, current_namespace]] }

    asserts('output cached by an earlier version for the same key parts is not read') do
      Rabl.configuration.cache_engine = memory_cache
      a = item(47)
      render("object @item\nattributes :id", a)
      Rabl.configuration.cache_engine = earlier_version_cache(Rabl.configuration.cache_engine)
      a.id = 470
      render("object @item\nattributes :id", a)
    end.equals '{"id":470}'
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
      stub.proxy(Rabl::TemplateCacheKey).digest { |digest| digests += 1; digest }
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

    asserts('one partial reached through two view paths in one render renders each') do
      shared = Dir.mktmpdir
      File.open(File.join(shared, 'leaf.rabl'), 'w') { |f| f.write("object @item\ncache root_object\nextends 'base'\n") }
      paths = topic.map { |dir| [dir, shared].inspect }
      template = "object @item\nnode(:a) { |i| partial('leaf', :object => i.owner, :view_path => #{paths[0]}) }\n" \
        "node(:b) { |i| partial('leaf', :object => i.owner, :view_path => #{paths[1]}) }"
      begin
        render(template, item(40, item(41)))
      ensure
        FileUtils.rm_rf(shared)
      end
    end.equals '{"a":{"id":41},"b":{"name":"item41"}}'

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

  # Without child roots, a nested rendering has the same shape in JSON and XML
  context 'with a partial for each format and no child roots' do
    setup do
      Rabl.configuration.include_child_root = false
      @dir = Dir.mktmpdir
      {
        'base.json' => "node(:picked) { 'json' }\n",
        'base.xml' => "node(:picked) { 'xml' }\n",
        'item' => "object @item\ncache ['v1', root_object]\nattributes :id\nextends 'base'\n",
        'plain_item' => "object @item\nattributes :id\nextends 'base'\n"
      }.each { |name, source| File.open(File.join(@dir, "#{name}.rabl"), 'w') { |f| f.write(source) } }
      @dir
    end

    # Renders the template in each format in turn, with one cache, and returns
    # the partial each rendering picked
    helper(:picked_in) do |formats, template, object|
      Rabl.configuration.cache_engine = memory_cache
      formats.map do |format|
        render(template, object, :format => format, :view_path => topic).scan(/"picked":"(\w+)"|<picked>(\w+)</).flatten.compact.uniq
      end
    end

    asserts('cached collection items render each format\'s partial, JSON first') do
      picked_in(%w(json xml), "collection @items\nextends 'item'", [item(100), item(101)])
    end.equals [%w(json), %w(xml)]

    asserts('cached collection items render each format\'s partial, XML first') do
      picked_in(%w(xml json), "collection @items\nextends 'item'", [item(102), item(103)])
    end.equals [%w(xml), %w(json)]

    asserts('a cached child block renders each format\'s partial') do
      picked_in(%w(xml json), "object @item\nchild(:owner => :owner) { cache root_object; extends 'base' }", item(104, item(105)))
    end.equals [%w(xml), %w(json)]

    asserts('a cached partial rendered in a node renders each format\'s partial') do
      picked_in(%w(json xml), "object @item\nnode(:owner) { |i| partial('item', :object => i.owner) }", item(106, item(107)))
    end.equals [%w(json), %w(xml)]

    context 'and cache_all_output' do
      setup { Rabl.configuration.cache_all_output = true; topic }

      asserts('collection items render each format\'s partial') do
        picked_in(%w(xml json), "collection @items\nextends 'plain_item'", [item(108), item(109)])
      end.equals [%w(xml), %w(json)]
    end

    # Rails' lookup takes the request's format, which can differ from the one rendered
    context 'under Rails' do
      setup do
        ::Rails = Module.new
        ::Rails.define_singleton_method(:version) { "3.2.22" }
        ::ActionPack = Module.new
        ::ActionPack::VERSION = Module.new
        ::ActionPack::VERSION::MAJOR = 3
        ::ActionPack::VERSION::MINOR = 2
        ::ActionController = Module.new
        ::ActionController::Base = Class.new { def self.perform_caching; true; end }
        topic
      end

      # A Rails view for a request in the given format, whose lookup finds templates
      # named for that format or for none
      helper(:rails_view) do |request_format|
        dir = topic
        lookup_context = Object.new
        lookup_context.define_singleton_method(:find) do |name, prefixes, partial, keys, options|
          path = ["#{name}.#{options[:formats].first}.rabl", "#{name}.rabl"].map { |file| File.join(dir, file) }.find { |file| File.exist?(file) }
          path ? Struct.new(:identifier).new(path) : raise("Missing template #{name}")
        end
        request = Struct.new(:format).new(request_format)
        scope = Object.new
        scope.define_singleton_method(:lookup_context) { lookup_context }
        scope.define_singleton_method(:view_paths) { [dir] }
        scope.define_singleton_method(:request) { request }
        scope
      end

      asserts('cached collection items render XML with the partials of each request\'s format') do
        Rabl.configuration.cache_engine = memory_cache
        [:json, :xml].map do |request_format|
          Rabl::Engine.new("collection @items\nextends 'item'", :format => 'xml').render(rails_view(request_format), :object => [item(110)]).scan(/<picked>(\w+)</).flatten
        end
      end.equals [%w(json), %w(xml)]

      asserts('cached items rendered as XML in an HTML request and in a JSON request render their own partials') do
        Rabl.configuration.cache_engine = memory_cache
        [:html, :json].map do |request_format|
          Rabl::Engine.new("object @item\ncache ['v1', @item]\nattributes :id\nextends 'base'", :format => 'xml').render(rails_view(request_format), :object => item(111)).scan(/<picked>(\w+)</).flatten
        end
      end.equals [%w(xml), %w(json)]

      asserts('child-block extends and node partials rendered as XML in an HTML request use the XML templates') do
        source = "object @item\nattributes :id\nchild(:itself => :c) { extends 'base' }\nnode(:part) { |i| partial('base', :object => i) }"
        Rabl::Engine.new(source, :format => 'xml').render(rails_view(:html), :object => item(112)).scan(/<picked>(\w+)</).flatten
      end.equals %w(xml xml)

      teardown do
        Object.send(:remove_const, :Rails)
        Object.send(:remove_const, :ActionPack)
        Object.send(:remove_const, :ActionController)
      end
    end

    teardown { FileUtils.rm_rf(@dir) }
  end

  context 'with templates rendered for each item' do
    setup do
      @dir = Dir.mktmpdir
      {
        'base' => "object @item\ncache @item\nattributes :id\n",
        'versioned' => "object @item\ncache ['v1', @item]\nattributes :id\n",
        'aliased' => "object @item => :thing\ncache @item\nattributes :id\n",
        'cached_first' => "cache ['v1', @item]\nobject @item\nattributes :id\n",
        'versioned_list' => "collection @items\ncache ['v1', @items]\nattributes :id\n",
        'viewer_ro' => "object @item\ncache [root_object, viewer]\nattributes :id\nnode(:mine, :if => lambda { |i| viewer.equal?(i) }) { true }\n",
        'viewer_ivar' => "object @item\ncache ['v1', @item, viewer]\nattributes :id\nnode(:mine, :if => lambda { |i| viewer.equal?(i) }) { true }\n"
      }.each { |name, source| File.open(File.join(@dir, "#{name}.rabl"), 'w') { |f| f.write(source) } }
      @dir
    end

    # Renders with @item set to the outer object, as a controller would
    helper(:render_for) do |source, object|
      scope = Object.new
      scope.instance_variable_set(:@item, object)
      Rabl::Engine.new(source, :format => 'json', :view_path => topic).render(scope, :object => object)
    end

    # Renders with a `viewer` helper (like current_user) and @item set to outer
    helper(:render_as) do |viewer, outer, source, object|
      scope = Object.new
      scope.instance_variable_set(:@item, outer)
      scope.define_singleton_method(:viewer) { viewer }
      Rabl::Engine.new(source, :format => 'json', :view_path => topic).render(scope, :object => object)
    end

    asserts('a template extended in a child and caching the outer object renders each child') do
      Rabl.configuration.cache_engine = memory_cache
      template = "object @item\nextends 'base'\nchild(:owner => :owners) { extends 'base' }"
      outer = item(50, [item(51), item(52)])
      2.times.map { render_for(template, outer) }
    end.equals ['{"id":50,"owners":[{"owner":{"id":51}},{"owner":{"id":52}}]}'] * 2

    asserts('a partial caching the outer object renders each object') do
      Rabl.configuration.cache_engine = memory_cache
      render_for("object @item\nnode(:owners) { |i| i.owner.map { |o| partial('base', :object => o) } }", item(56, [item(57), item(58)]))
    end.equals '{"owners":[{"id":57},{"id":58}]}'

    asserts('items of a collection caching a key with an unset instance variable are cached apart') do
      Rabl.configuration.cache_engine = memory_cache
      items = [item(53), item(54), item(55)]
      first = render("collection @items\nextends 'versioned'", items, :view_path => topic)
      items.each { |i| i.id += 100 }
      [first, render("collection @items\nextends 'versioned'", items, :view_path => topic), Rabl.configuration.cache_engine.store.size]
    end.equals ['[{"id":53},{"id":54},{"id":55}]', '[{"id":53},{"id":54},{"id":55}]', 3]

    asserts('a template caching an instance variable that does not hold the rendered object renders each object') do
      Rabl.configuration.cache_engine = memory_cache
      [item(66), item(67)].map { |object| Rabl::Renderer.json(object, 'versioned', :view_path => topic, :scope => Object.new) }
    end.equals ['{"id":66}', '{"id":67}']

    context 'without read_multi' do
      setup { Rabl.configuration.use_read_multi = false; topic }

      asserts('items of a collection caching a key with an unset instance variable render each item') do
        Rabl.configuration.cache_engine = memory_cache
        items = [item(64), item(65)]
        first = render("collection @items\nextends 'versioned'", items, :view_path => topic)
        items.each { |i| i.id += 100 }
        [first, render("collection @items\nextends 'versioned'", items, :view_path => topic)]
      end.equals ['[{"id":64},{"id":65}]', '[{"id":64},{"id":65}]']

      asserts('a template naming its object with an alias and caching the outer object renders each child') do
        Rabl.configuration.cache_engine = memory_cache
        template = "object @item\nchild(:owner => :owners) { extends 'aliased' }"
        outer = item(60, [item(61), item(62)])
        2.times.map { render_for(template, outer) }
      end.equals ['{"owners":[{"owner":{"id":61}},{"owner":{"id":62}}]}'] * 2

      asserts('items of a collection render each item when the template calls cache before object') do
        Rabl.configuration.cache_engine = memory_cache
        render("collection @items\nextends 'cached_first'", [item(68), item(69)], :view_path => topic)
      end.equals '[{"id":68},{"id":69}]'

      asserts('a collection rendered as a partial and caching an unset instance variable renders each collection') do
        Rabl.configuration.cache_engine = memory_cache
        template = "object @item\nnode(:friends) { |i| partial('versioned_list', :object => i.owner) }"
        [item(75, [item(76), item(77)]), item(78, [item(79)])].map { |object| render(template, object, :view_path => topic) }
      end.equals ['{"friends":[{"id":76},{"id":77}]}', '{"friends":[{"id":79}]}']

      asserts('items of a collection are cached apart when the instance variable holds a data hash') do
        Rabl.configuration.cache_engine = memory_cache
        items = [item(80), item(81)]
        render_as(nil, { :theme => 1 }, "collection @items\nextends 'versioned'", items)
      end.equals '[{"id":80},{"id":81}]'

      asserts('an item keyed with root_object and a nil viewer does not get another viewer\'s output') do
        Rabl.configuration.cache_engine = memory_cache
        items = [item(82), item(83)]
        [items[0], nil].map { |viewer| render_as(viewer, nil, "collection @items\nextends 'viewer_ro'", items) }
      end.equals ['[{"id":82,"mine":true},{"id":83}]', '[{"id":82},{"id":83}]']

      asserts('an item keyed with the instance variable and a nil viewer does not get another viewer\'s output') do
        Rabl.configuration.cache_engine = memory_cache
        items = [item(84), item(85)]
        [items[0], nil].map { |viewer| render_as(viewer, nil, "collection @items\nextends 'viewer_ivar'", items) }
      end.equals ['[{"id":84,"mine":true},{"id":85}]', '[{"id":84},{"id":85}]']

      asserts('a child keyed with the viewer stays apart per viewer when the outer object is the viewer') do
        Rabl.configuration.cache_engine = memory_cache
        friend = item(86)
        other, own = item(87, [friend]), item(88, [friend])
        template = "object @item\nchild(:owner => :owners) { extends 'viewer_ro' }"
        [render_as(friend, other, template, other), render_as(own, own, template, own)]
      end.equals ['{"owners":[{"owner":{"id":86,"mine":true}}]}', '{"owners":[{"owner":{"id":86}}]}']

      teardown { Rabl.configuration.use_read_multi = true }
    end

    teardown { FileUtils.rm_rf(@dir) }
  end

  context 'against earlier versions' do
    setup do
      Rabl.configuration.cache_engine = memory_cache
      @dir = Dir.mktmpdir
      File.open(File.join(@dir, 'cached_item.rabl'), 'w') { |f| f.write("object @item\ncache root_object\nattributes :id\n") }
      @dir
    end

    asserts('a template\'s cache key is in the current namespace') do
      Rabl.configuration.cache_engine = memory_cache
      render("object @item\ncache @item\nattributes :id", item(90))
      Rabl.configuration.cache_engine.calls.uniq
    end.equals { [[:fetch, current_namespace]] }

    asserts('a child block\'s cache key is in the current namespace') do
      Rabl.configuration.cache_engine = memory_cache
      render("object @item\nchild(:owner => :owner) { cache root_object; attributes :id }", item(91, item(92)))
      Rabl.configuration.cache_engine.calls.uniq
    end.equals { [[:fetch, current_namespace]] }

    asserts('the keys a collection reads together and writes are in the current namespace') do
      Rabl.configuration.cache_engine = memory_cache
      render("collection @items\nextends 'cached_item'", [item(93), item(94)], :view_path => topic)
      Rabl.configuration.cache_engine.calls.uniq
    end.equals { [[:read_multi, current_namespace], [:write, current_namespace]] }

    asserts('output cached by an earlier version for the same key parts is not read') do
      Rabl.configuration.cache_engine = memory_cache
      template = "object @item\ncache @item\nattributes :id\nchild(:owner => :owner) { cache root_object; attributes :id }"
      a = item(95, item(96))
      render(template, a)
      Rabl.configuration.cache_engine = earlier_version_cache(Rabl.configuration.cache_engine)
      a.id = 950
      a.owner.id = 960
      render(template, a)
    end.equals '{"id":950,"owner":{"id":960}}'

    asserts('collection items cached by an earlier version for the same key parts are not read') do
      Rabl.configuration.cache_engine = memory_cache
      items = [item(97), item(98)]
      render("collection @items\nextends 'cached_item'", items, :view_path => topic)
      Rabl.configuration.cache_engine = earlier_version_cache(Rabl.configuration.cache_engine)
      items.each { |i| i.id += 1000 }
      render("collection @items\nextends 'cached_item'", items, :view_path => topic)
    end.equals '[{"id":1097},{"id":1098}]'

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
