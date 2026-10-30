# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
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

    asserts('a partial is cached once for the templates that extend it') do
      a = item(16)
      first = render("object @item\nextends 'item_id'", a, :view_path => topic)
      a.id = 160
      [first, render("object @item\nextends 'item_id'\nattributes :name", a, :view_path => topic)]
    end.equals ['{"id":16}', '{"name":"item16","id":16}']

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

  teardown { Rabl.reset_configuration! }
end
