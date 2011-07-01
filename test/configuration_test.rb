require File.expand_path('../teststrap', __FILE__)
require File.expand_path('../../lib/rabl', __FILE__)

context "Rabl::Configuration" do

  context "with defaults" do
    setup { Rabl.configuration }

    asserts(:include_json_root).equals true
    asserts(:include_xml_root).equals false
    asserts(:enable_json_callbacks).equals false
    asserts(:json_engine).equals nil
  end

  context "with configuration" do
    setup do
      Rabl.configure do |config|
        config.include_json_root     = false
        config.include_xml_root      = true
        config.enable_json_callbacks = true
        config.json_engine           = :yajl
      end
      Rabl.configuration
    end

    asserts(:include_json_root).equals false
    asserts(:include_xml_root).equals true
    asserts(:enable_json_callbacks).equals true
    asserts(:json_engine).equals :yajl

    teardown do
      Rabl.configure do |config|
        config.json_engine = MultiJson.default_engine
      end
    end
  end

end
