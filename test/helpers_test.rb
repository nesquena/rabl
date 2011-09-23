require 'tmpdir'
require 'pathname'
require File.expand_path('../../lib/rabl', __FILE__)

class TestHelper
  include Rabl::Helpers
end

context "Rabl::Helpers" do
  context "fetch_source" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }
    
    setup do
      ::Rails = stub(Class.new)
      ::Rails.root.returns(tmp_path)
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts "content"
      end
      File.open(tmp_path + "test_v1.json.rabl", "w") do |f|
        f.puts "content_v1"
      end
      FileUtils.touch tmp_path + "test_v2.json.rabl"
      [TestHelper.new.fetch_source('test', :view_path => tmp_path.to_s),
       TestHelper.new.fetch_source('test_v1', :view_path => tmp_path.to_s)]
    end
    
    asserts(:first).equals {["content\n", (tmp_path + "test.json.rabl").to_s ]}
    asserts(:last).equals {["content_v1\n", (tmp_path + "test_v1.json.rabl").to_s ]}
    teardown { Object.send(:remove_const, :Rails) }
  end

  context "fetch_source" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

    setup do
      ::Rails = stub(Class.new)
      ::Rails.root.returns(tmp_path)
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts "content"
      end
      TestHelper.new.fetch_source('test', :view_path => tmp_path.to_s)
    end
    asserts('detects file.rabl') { topic }.equals do
      ["content\n", (tmp_path + 'test.rabl').to_s]
    end
    teardown { Object.send(:remove_const, :Rails) }
  end

  context "fetch_source" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

    setup do
      ::Rails = stub(Class.new)
      ::Rails.root.returns(tmp_path)
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts "content"
      end
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts "content2"
      end
      TestHelper.new.fetch_source('test', :view_path => tmp_path.to_s)
    end
    asserts('detects file.json.rabl first') { topic }.equals do
      ["content2\n", (tmp_path + 'test.json.rabl').to_s]
    end
    teardown { Object.send(:remove_const, :Rails) }
  end
end
