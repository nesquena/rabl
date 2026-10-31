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

    teardown { Rabl.reset_configuration! }
  end # custom json, symbol

  context 'custom JSON engine configured as Class' do
    setup do
      Rabl.configure do |c|
        c.json_engine = ActiveSupport::JSON
      end
    end

    asserts('uses a custom JSON engine') { topic.json_engine.to_s == 'ActiveSupport::JSON' }

    teardown { Rabl.reset_configuration! }
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

    # A json_engine wrapper that calls Oj.dump without options sees Oj.default_options
    helper(:wrapper_script) do |before_rabl|
      "require 'oj'; #{before_rabl}; require 'rabl'; " \
      "price = Class.new { def to_json(*); %q(\"$5\"); end }.new; " \
      "src = %Q(object false\\nnode(:price) { @price }\\nnode(:nan) { 0.0/0 }\\n); " \
      "render = lambda { Rabl::Renderer.new(src, nil, :format => 'json', :locals => { :price => price }).render }; " \
      "default_engine = render.call; " \
      "Rabl.configure { |c| c.json_engine = Class.new { def self.dump(o); Oj.dump(o); end } }; " \
      "print [Oj.default_options[:mode], default_engine, (render.call rescue $!.class.name)].inspect"
    end

    asserts('without app options, rabl sets its Oj defaults as before, so wrappers keep its output') do
      rabl_subprocess(wrapper_script(''))
    end.equals [:compat, '{"price":"$5","nan":NaN}', '{"price":"$5","nan":NaN}'].inspect

    asserts('with app options set before rabl, wrappers follow the app and rabl keeps its output') do
      rabl_subprocess(wrapper_script('Oj.default_options = { :mode => :strict }'))
    end.equals [:strict, '{"price":"$5","nan":NaN}', 'TypeError'].inspect

    # Oj before 3.17.7 hands the options given to Oj.dump on to to_json, which json 3.x
    # rejects, so rabl passes none when Oj's global options already match its own
    helper(:oj_dump_arity_script) do |after_rabl|
      "require 'oj'; require 'rabl'; #{after_rabl}; $arity = []; " \
      "class << Oj; alias_method :rabl_test_dump, :dump; def dump(*a); $arity << a.size; rabl_test_dump(*a); end; end; " \
      "Rabl::Renderer.new(%Q(object false\\nnode(:t) { Time.utc(2020) }\\n), nil, :format => 'json').render; " \
      "print $arity.inspect"
    end

    # Older Oj hands Oj.dump's options on to to_json (rejected by json 3.x), so there rabl
    # keeps setting its options globally at load and calls Oj.dump(obj), as before
    asserts('with Oj before 3.17.7, rabl overwrites the app options at load and passes none') do
      rabl_subprocess("require 'oj'; Oj.send(:remove_const, :VERSION); Oj.const_set(:VERSION, '3.16.0'); " \
                      "Oj.default_options = { :mode => :strict }; " + oj_dump_arity_script('').sub("require 'oj'; ", '') \
                      .sub("print $arity.inspect", "print [Oj.default_options[:mode], $arity].inspect"))
    end.equals [:compat, [1]].inspect

    asserts('without app options, rabl calls Oj.dump with no options') do
      rabl_subprocess(oj_dump_arity_script(''))
    end.equals '[1]'

    asserts('with a :rails mode the app sets after rabl, rabl calls Oj.dump with no options') do
      rabl_subprocess(oj_dump_arity_script('Oj.default_options = { :mode => :rails }'))
    end.equals '[1]'

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

  context 'oj_version_at_least?' do
    asserts('compares versions part by part as numbers') do
      %w[3.1.2 3.1.3 3.10.0 3.17.6 3.17.7 4.0.0].map { |v| Rabl::Configuration.oj_version_at_least?(v, [3, 17, 7]) }
    end.equals [false, false, false, false, true, true]

    asserts('treats a shorter version as lower') do
      [Rabl::Configuration.oj_version_at_least?('3.17', [3, 17, 7]), Rabl::Configuration.oj_version_at_least?('3.1.3', [3, 1, 3])]
    end.equals [false, true]
  end

  context 'raise on missing attributes' do
    setup do
      Rabl.configure do |c|
        c.raise_on_missing_attribute = true
      end
    end

    asserts(:raise_on_missing_attribute).equals true

    teardown { Rabl.reset_configuration! }
  end # raise on missing

  context 'replace nil values with empty strings' do
    setup do
      Rabl.configure do |c|
        c.replace_nil_values_with_empty_strings = true
      end
    end

    asserts(:replace_nil_values_with_empty_strings).equals true

    teardown { Rabl.reset_configuration! }
  end # replace nil values with empty strings

  context 'replace empty string values with nil values' do
    setup do
      Rabl.configure do |c|
        c.replace_empty_string_values_with_nil_values = true
      end
    end

    asserts(:replace_empty_string_values_with_nil_values).equals true

    teardown { Rabl.reset_configuration! }
  end # replace empty string values with nil values

  context 'exclude nil values' do
    setup do
      Rabl.configure do |c|
        c.exclude_nil_values = true
      end
    end

    asserts(:exclude_nil_values).equals true

    teardown { Rabl.reset_configuration! }
  end # exclude nil values

  context 'exclude empty values in collections' do
    setup do
      Rabl.configure do |c|
        c.exclude_empty_values_in_collections = true
      end
    end

    asserts(:exclude_empty_values_in_collections).equals true

    teardown { Rabl.reset_configuration! }
  end # exclude empty values in collections
end
