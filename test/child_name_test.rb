# frozen_string_literal: true

require 'json'
require 'rbconfig'
require File.expand_path('../teststrap', __FILE__)

module ChildNameTest
  Owner = Struct.new(:favorites)

  # Renders templates against ActiveRecord models in a subprocess (see the script)
  def self.render_with_active_record(*sources)
    script = File.expand_path('../support/active_record_child_names.rb', __FILE__)
    lib = File.expand_path('../../lib', __FILE__)
    IO.popen([RbConfig.ruby, '-I', lib, script, *sources], &:read).lines.map { |line| JSON.parse(line) }
  end
end

# #394: a collection child is named after the symbol the template wrote
context "Rabl::Builder#child naming" do
  context "with ActiveRecord associations" do
    setup do
      ChildNameTest.render_with_active_record(
        "object @product\nchild(:units) { attribute :name }\n",
        "object @product\nchild(:units, :object_root => false) { attribute :name }\nchild(:parts, :object_root => false) { attribute :name }\n",
        "object @product\nchild(:units => :units) { attribute :name }\n",
        "object false\nchild(@relation, :object_root => false) { attribute :name }\n")
    end

    asserts "a has_many :through with :source is keyed by the association name" do
      topic[0]
    end.equals({ "product" => { "units" => [{ "unit" => { "name" => "leg" } }] } })

    asserts "two associations on the same table keep separate keys" do
      topic[1]
    end.equals({ "product" => { "units" => [{ "name" => "leg" }], "parts" => [{ "name" => "top" }] } })

    asserts "it matches the explicit alias form" do
      topic[0] == topic[2]
    end

    asserts "a relation passed without a name is still named after its table" do
      topic[3]
    end.equals({ "product_units" => [{ "name" => "top" }] })
  end

  context "with plain arrays" do
    setup do
      ChildNameTest::Owner.new([Hobby.new('chess')])
    end

    asserts "the written symbol wins over the first item's class" do
      JSON.parse(Rabl::Renderer.new("object @owner => :owner\nchild(:favorites) { attribute :name }\n", topic, :format => 'json').render)
    end.equals({ "owner" => { "favorites" => [{ "favorite" => { "name" => "chess" } }] } })

    asserts "a :root option renames the key but items keep the written symbol's singular" do
      JSON.parse(Rabl::Renderer.new("object @owner => :owner\nchild(:favorites, :root => :likes) { attribute :name }\n", topic, :format => 'json').render)
    end.equals({ "owner" => { "likes" => [{ "favorite" => { "name" => "chess" } }] } })

    asserts "an array passed without a name is still named after its items" do
      Rabl::Renderer.new("object false\nchild(@favorites, :object_root => false) { attribute :name }\n", nil,
        :format => 'json', :locals => { :favorites => topic.favorites }).render
    end.equals '{"hobbies":[{"name":"chess"}]}'
  end
end
