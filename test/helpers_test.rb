require 'tmpdir'
require 'pathname'
require File.expand_path('../../lib/rabl', __FILE__)

class TestHelper
  include Rabl::Helpers
  def initialize(options = {})
    @options = options
  end
end

context "Rabl::Helpers" do
  helper(:tmp_path)    { @tmp_path ||= Pathname.new(Dir.mktmpdir) }
  helper(:test_helper) { TestHelper.new({:format => 'json'}) }

  setup do
    ::Rails = stub(Class.new)
    ::Rails.root.returns(tmp_path)
  end
  teardown { Object.send(:remove_const, :Rails) }

  context "#fetch_source" do

    setup do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts "content"
      end
      File.open(tmp_path + "test_v1.json.rabl", "w") do |f|
        f.puts "content_v1"
      end
      FileUtils.touch tmp_path + "test_v2.json.rabl"
      [test_helper.fetch_source('test', :view_path => tmp_path.to_s),
       test_helper.fetch_source('test_v1', :view_path => tmp_path.to_s)]
    end

    asserts(:first).equals {["content\n", (tmp_path + "test.json.rabl").to_s ]}
    asserts(:last).equals {["content_v1\n", (tmp_path + "test_v1.json.rabl").to_s ]}
  end

  context "#fetch_source" do
    setup do
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts "content"
      end
      test_helper.fetch_source('test', :view_path => tmp_path.to_s)
    end

    asserts('detects file.rabl') { topic }.equals do
      ["content\n", (tmp_path + 'test.rabl').to_s]
    end
  end

  context "#fetch_source" do
    setup do
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts "content"
      end
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts "content2"
      end
      test_helper.fetch_source('test', :view_path => tmp_path.to_s)
    end

    asserts('detects file.json.rabl first') { topic }.equals do
      ["content2\n", (tmp_path + 'test.json.rabl').to_s]
    end
  end

  context "#fetch_source" do
    setup do
      File.open(tmp_path + "user.rabl", "w") do |f|
        f.puts "user.rabl"
      end
    end

    asserts "that it strictly finds a single file" do
      test_helper.fetch_source('user', :view_path => tmp_path.to_s)
    end.matches "user.rabl"

    asserts "that it strictly finds an exact match" do
      test_helper.fetch_source('usr', :view_path => tmp_path.to_s)
    end.equals nil
  end

  context "#fetch_source" do
    setup do
      File.open(tmp_path + "user.json.rabl", "w") do |f|
        f.puts "user.json.rabl"
      end
    end

    asserts "that it finds user.json.rabl when finding 'user'" do
      test_helper.fetch_source('user', :view_path => tmp_path.to_s)
    end.matches "user.json.rabl"

    asserts "that it finds user.json.rabl when finding 'user.json'" do
      test_helper.fetch_source('user.json', :view_path => tmp_path.to_s)
    end.matches "user.json.rabl"

    asserts "that it finds user.json.rabl when finding 'user.xml'" do
      test_helper.fetch_source('user.xml', :view_path => tmp_path.to_s)
    end.equals nil
  end

end
