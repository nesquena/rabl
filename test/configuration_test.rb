require File.expand_path('../teststrap', __FILE__)

context 'Rabl::Configuration' do
  context 'defaults' do
    # multi_json compatibility TODO
    helper(:json_engine) { MultiJson.respond_to?(:adapter) ? MultiJson.adapter : MultiJson.engine }
    setup { Rabl.configuration }

    asserts(:include_json_root).equals true
    asserts(:include_child_root).equals true
    asserts(:include_xml_root).equals false
    asserts(:enable_json_callbacks).equals false
    asserts(:view_paths).equals []
    asserts(:json_engine).equals { json_engine }
    asserts(:cache_engine).is_a?(Rabl::CacheEngine)
  end

  context 'custom JSON engine configured as Symbol' do
    setup do
      Rabl.configure do |c|
        c.json_engine = :yajl
      end
    end

    asserts('uses a custom JSON engine') { topic.json_engine.to_s =~ /MultiJson.*::Yajl/ }
  end # custom json, symbol

  context 'custom JSON engine configured as Class' do
    setup do
      Rabl.configure do |c|
        c.json_engine = ActiveSupport::JSON
      end
    end

    asserts('uses a custom JSON engine') { topic.json_engine.to_s == 'ActiveSupport::JSON' }
  end # custom JSON, class

  context 'invalid JSON engine configured' do
    asserts {
      Rabl.configure do |c|
        c.json_engine = Kernel
      end
    }.raises(RuntimeError)
  end # invalid
end
