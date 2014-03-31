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
