require File.expand_path('../teststrap', __FILE__)
require File.expand_path('../../lib/rabl', __FILE__)

context 'Rabl::Configuration' do
  context 'defaults' do
    setup { Rabl.configuration }

    asserts(:include_json_root).equals true
    asserts(:include_xml_root).equals false
    asserts(:enable_json_callbacks).equals false
    asserts(:json_engine).equals MultiJson.engine
  end

  context 'custom JSON engine' do
    setup do
      Rabl.configure do |c|
        c.json_engine = :yajl
      end
    end

    asserts('uses a custom JSON engine') { topic.json_engine == MultiJson::Engines::Yajl }
  end
end
