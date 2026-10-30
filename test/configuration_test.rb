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

    # Renders with the app's Oj.default_options changed after rabl was loaded, then restores them
    helper(:render_with_oj) do |oj_options, source, json_engine|
      saved = Oj.default_options
      begin
        Oj.default_options = oj_options
        Rabl.configuration.json_engine = json_engine
        Rabl::Renderer.new(source, nil, :format => 'json', :locals => { :price => money }).render
      ensure
        Oj.default_options = saved
        Rabl.reset_configuration!
      end
    end

    helper(:rabl_subprocess) do |script|
      IO.popen([RbConfig.ruby, '-I', File.expand_path('../../lib', __FILE__), '-e', script, { :err => [:child, :out] }], &:read)
    end

    setup { Rabl.reset_configuration! }
    teardown { Rabl.reset_configuration! }

    asserts('requiring rabl keeps options the app set before') do
      rabl_subprocess("require 'oj'; Oj.default_options = { :mode => :strict, :time_format => :unix, :use_to_json => false }; " \
                      "require 'rabl'; print Oj.default_options.values_at(:mode, :time_format, :use_to_json).inspect")
    end.equals '[:strict, :unix, false]'

    asserts('options the app set before loading rabl do not change its output') do
      rabl_subprocess("require 'oj'; Oj.default_options = { :mode => :strict, :use_to_json => false }; require 'rabl'; " \
                      "price = Class.new { def to_json(*); %q(\"$5\"); end }.new; " \
                      "print Rabl::Renderer.new(%Q(object false\nnode(:price) { @price }\nnode(:nan) { 0.0/0 }\n), nil, " \
                      ":format => 'json', :locals => { :price => price }).render")
    end.equals '{"price":"$5","nan":NaN}'

    asserts('NaN and Infinity render as before') do
      render_with_oj({}, "object false\nnode(:x) { 0.0/0 }\nnode(:y) { 1.0/0 }\nnode(:z) { -1.0/0 }\n", nil)
    end.equals '{"x":NaN,"y":Infinity,"z":-Infinity}'

    asserts('rendering ignores a :strict mode the app sets after') do
      render_with_oj({ :mode => :strict, :use_to_json => false }, "object false\nnode(:price) { @price }\n", nil)
    end.equals '{"price":"$5"}'

    asserts('an explicitly configured Oj gets the same options') do
      render_with_oj({ :mode => :strict, :use_to_json => false }, "object false\nnode(:price) { @price }\n", Oj)
    end.equals '{"price":"$5"}'

    asserts('a :rails mode the app sets after loading rabl is followed, as before') do
      render_with_oj({ :mode => :rails }, "object false\nnode(:html) { '</script>&' }\nnode(:nan) { 0.0/0 }\n", nil)
    end.equals '{"html":"\\u003c/script\\u003e\\u0026","nan":null}'

    asserts('a custom engine with dump is still used') do
      engine = Object.new
      def engine.dump(hash); "custom:#{hash.keys.join(',')}"; end
      render_with_oj({}, "object false\nnode(:price) { 1 }\n", engine)
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
