# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require File.expand_path('../teststrap', __FILE__)

context 'Rabl::CacheEngine' do
  context '#write without Rails' do
    setup { Rabl::CacheEngine.new }

    asserts('stores the given value') do
      topic.write('key', 'value')
      topic.fetch('key', {}) { 'fallback' }
    end.equals 'value'
  end

  context 'rendering a cached collection without Rails' do
    helper(:item) do |id|
      Class.new do
        attr_accessor :id, :cache_key
        def initialize(id); @id, @cache_key = id, "item/#{id}"; end
      end.new(id)
    end

    setup do
      Rabl.configure do |config|
        config.perform_caching = true
        config.include_json_root = false
        config.cache_engine = Rabl::CacheEngine.new
      end
      dir = Dir.mktmpdir
      File.open(File.join(dir, 'item.rabl'), 'w') { |f| f.write("object @item\ncache @item\nattributes :id\n") }
      dir
    end

    asserts('renders each item') do
      Rabl::Engine.new("collection @items\nextends 'item'", :format => 'json', :view_path => topic).
        render(Object.new, :object => [item(1), item(2)])
    end.equals '[{"id":1},{"id":2}]'

    asserts('serves cached fragments on the next render') do
      items = [item(1), item(2)]
      template = "collection @items\nextends 'item'\nattributes :id => :fresh_id"
      engine = lambda { Rabl::Engine.new(template, :format => 'json', :view_path => topic).render(Object.new, :object => items) }
      engine.call
      items.each { |i| i.id += 10 }
      engine.call
    end.equals '[{"fresh_id":11,"id":1},{"fresh_id":12,"id":2}]'

    teardown do
      FileUtils.rm_rf(topic)
      Rabl.reset_configuration!
    end
  end
end
