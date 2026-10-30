# frozen_string_literal: true

require 'rbconfig'
require File.expand_path('../teststrap', __FILE__)

context 'Rabl::Configuration' do
  context 'defaults' do
    # multi_json compatibility TODO
    helper(:json_engine) { ::Oj }
    setup { Rabl.configuration }

    asserts(:include_json_root).equals true
    asserts(:include_child_root).equals true
    asserts(:include_xml_root).equals false
    asserts(:enable_json_callbacks).equals false
    asserts(:view_paths).equals []
    asserts(:json_engine).equals { json_engine }
    asserts(:cache_engine).is_a?(Rabl::CacheEngine)
    asserts(:replace_nil_values_with_empty_strings).equals false
    asserts(:replace_empty_string_values_with_nil_values).equals false
    asserts(:exclude_nil_values).equals false
    asserts(:exclude_empty_values_in_collections).equals false
  end

  context 'custom JSON engine configured as Symbol' do
    setup do
      Rabl.configure do |c|
        c.json_engine = :oj
      end
    end

    asserts('uses a custom JSON engine') { topic.json_engine.to_s =~ /oj/i }
  end # custom json, symbol

  context 'custom JSON engine configured as Class' do
    setup do
      Rabl.configure do |c|
        c.json_engine = ActiveSupport::JSON
      end
    end

    asserts('uses a custom JSON engine') { topic.json_engine.to_s == 'ActiveSupport::JSON' }
  end # custom JSON, class

  # #744: rabl leaves the app's Oj.default_options alone and passes its own per call
  context 'Oj default options' do
    helper(:money) do
      Class.new { def to_json(*); '"$5"'; end }.new
    end

    setup do
      @oj_defaults = Oj.default_options
      Rabl.reset_configuration!
      Rabl.configuration
    end

    teardown do
      Oj.default_options = @oj_defaults
      Rabl.reset_configuration!
    end

    asserts('requiring rabl keeps options the app set before') do
      script = "require 'oj'; Oj.default_options = { :mode => :strict, :time_format => :unix, :use_to_json => false }; " \
               "require 'rabl'; print Oj.default_options.values_at(:mode, :time_format, :use_to_json).inspect"
      IO.popen([RbConfig.ruby, '-I', File.expand_path('../../lib', __FILE__), '-e', script], &:read)
    end.equals '[:strict, :unix, false]'

    asserts('rendering ignores options the app sets after') do
      Oj.default_options = { :mode => :strict, :use_to_json => false }
      Rabl::Renderer.new("object false\nnode(:price) { @price }\n", nil, :format => 'json', :locals => { :price => money }).render
    end.equals '{"price":"$5"}'

    asserts('an explicitly configured Oj gets the same options') do
      Oj.default_options = { :mode => :strict, :use_to_json => false }
      topic.json_engine = Oj
      Rabl::Renderer.new("object false\nnode(:price) { @price }\n", nil, :format => 'json', :locals => { :price => money }).render
    end.equals '{"price":"$5"}'

    asserts('a custom engine with dump is still used') do
      engine = Object.new
      def engine.dump(hash); "custom:#{hash.keys.join(',')}"; end
      topic.json_engine = engine
      Rabl::Renderer.new("object false\nnode(:price) { 1 }\n", nil, :format => 'json').render
    end.equals 'custom:price'
  end # Oj default options

  context 'raise on missing attributes' do
    setup do
      Rabl.configure do |c|
        c.raise_on_missing_attribute = true
      end
    end

    asserts(:raise_on_missing_attribute).equals true
  end # raise on missing

  context 'replace nil values with empty strings' do
    setup do
      Rabl.configure do |c|
        c.replace_nil_values_with_empty_strings = true
      end
    end

    asserts(:replace_nil_values_with_empty_strings).equals true
  end # replace nil values with empty strings

  context 'replace empty string values with nil values' do
    setup do
      Rabl.configure do |c|
        c.replace_empty_string_values_with_nil_values = true
      end
    end

    asserts(:replace_empty_string_values_with_nil_values).equals true
  end # replace empty string values with nil values

  context 'exclude nil values' do
    setup do
      Rabl.configure do |c|
        c.exclude_nil_values = true
      end
    end

    asserts(:exclude_nil_values).equals true
  end # exclude nil values

  context 'exclude empty values in collections' do
    setup do
      Rabl.configure do |c|
        c.exclude_empty_values_in_collections = true
      end
    end

    asserts(:exclude_empty_values_in_collections).equals true
  end # exclude empty values in collections
end
