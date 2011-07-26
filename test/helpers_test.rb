require 'tmpdir'
require 'pathname'
require File.expand_path('../../lib/rabl', __FILE__)

class TestHelper
  include Rabl::Helpers
end

context "Rabl::Helpers" do
  context "fetch_source" do
    setup do
      Dir.mktmpdir do |dir|
        tmp_path = Pathname.new dir
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
    end
    asserts(:first).equals "content\n"
    asserts(:last).equals "content_v1\n"
  end
end
