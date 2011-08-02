require File.expand_path('../teststrap', __FILE__)
require File.expand_path('../../lib/rabl', __FILE__)

context "Rabl::Configuration" do

  context "with defaults" do
    setup { Rabl.configuration }

    asserts(:include_json_root).equals true
    asserts(:include_xml_root).equals false
    asserts(:enable_json_callbacks).equals false
    asserts(:json_engine).equals MultiJson.engine
  end

  context "with configuration" do
    class CustomEncodeEngine; end

    setup do
      Rabl.configure do |config|
        config.json_engine = CustomEncodeEngine
      end
      Rabl.configuration
    end

    asserts(:json_engine).equals CustomEncodeEngine

    teardown do
      Rabl.reset_configuration!
    end
  end
end
