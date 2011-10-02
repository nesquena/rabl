require File.expand_path('../teststrap',   __FILE__)
require File.expand_path('../models/user', __FILE__)

context "Rabl::Builder" do

  helper(:builder)    { |obj,opt| Rabl::Builder.new(obj, opt) }
  helper(:get_result) { |obj| obj.instance_variable_get("@_result") }
  helper(:get_hash)   { |obj, root| obj.to_hash(:root => root) }

  setup do
    @users = [User.new, User.new]
    @user = User.new
    builder User.new, {}
  end

  context "#initialize" do
    asserts_topic.assigns :_object
    asserts_topic.assigns :options
    asserts_topic.assigns :_result
  end

  context "#to_hash" do

    context "when given a simple object" do

      setup { builder User.new, {} }
      asserts "that the object is set properly" do
        topic.attribute :name
        get_hash(topic, true)
      end.equivalent_to({ "user" => { :name => "rabl" } })

    end

    context "when given an object alias" do

     setup { builder({ User.new => "person" }, {}) }
      asserts "that the object is set properly" do
        topic.attribute :name
        get_hash(topic, true)
      end.equivalent_to({ "person" => { :name => "rabl" } })

    end

    context "when specified with no root" do

      setup { builder User.new, {} }
      asserts "that the object is set properly" do
        topic.attribute :name
        get_hash(topic, false)
      end.equivalent_to({ :name => "rabl" })

    end

  end

  context "#attribute" do

    context "when given an array" do

      asserts "that the node" do
        topic.attribute :name, :city
        get_result(topic)
      end.equivalent_to({:name => 'rabl', :city => 'irvine'})

      asserts "that with a non-existent attribute the node" do
        topic.attribute :fake
        get_result(topic)[:fake]
      end.nil

    end

    context "when given a Hash" do

      asserts "that using :as, the node" do
        topic.attribute :city, :as => 'foo'
        get_result(topic)
      end.equals({'foo'=>'irvine'})

      asserts "with multiple attributes, the node" do
        topic.attributes :city => :a, :age => :b
        get_result(topic)
      end.equivalent_to({:a => 'irvine', :b => 24, 'foo' => 'irvine'})

    end

  end

  context "#code" do

    asserts "that it has node :foo" do
      topic.code(:foo) { "bar" }
      get_result(topic)
    end.equivalent_to({:foo => 'bar'})

    asserts "that using object it has node :boo" do
      topic.code(:baz) { |u| u.city }
      get_result(topic)
    end.equivalent_to({:foo => 'bar', :baz => 'irvine'})
  end

  context "#child" do

    denies "that it generates if no data present" do
      topic.child nil
    end

    asserts "that it generates with a hash" do
      b = builder @user, {}
      mock(b).object_to_hash({ @user => :user },{ :root => false }).returns('xyz').subject

      b.child(@user => :user) { attribute :name }
      get_result(b)
    end.equivalent_to({ :user => 'xyz'})

    asserts "that it generates with a hash alias" do
      b = builder @user, {}

      b.child(@user => :person) { attribute :name }
      get_result(b)
    end.equivalent_to({ :person => { :name => "rabl" } })

    asserts "that it generates with an object" do
      b = builder @user, {}
      mock(b).data_name(@user) { :user }
      mock(b).object_to_hash(@user,{ :root => false }).returns('xyz').subject

      b.child(@user) { attribute :name }
      get_result(b)
    end.equivalent_to({ :user => 'xyz'})

    asserts "that it generates with an collection and child_root" do
      b = builder @user, { :child_root => true }
      mock(b).data_name(@users) { :users }
      mock(b).object_to_hash(@users,{ :root => true, :child_root => true }).returns('xyz').subject

      b.child(@users) { attribute :name }
      get_result(b)
    end.equivalent_to({ :users => 'xyz'})

    asserts "that it generates with an collection and no child root" do
      b = builder @user, { :child_root => false }
      mock(b).data_name(@users) { :users }
      mock(b).object_to_hash(@users,{ :root => false, :child_root => false }).returns('xyz').subject

      b.child(@users) { attribute :name }
      get_result(b)
    end.equivalent_to({ :users => 'xyz'})
  end

  context "#glue" do

    denies "that it generates if no data present" do
      topic.glue nil
    end

    asserts "that it generates the glue attributes" do
      b = builder @user, {}
      mock(b).object_to_hash(@user,{ :root => false }).returns({:user => 'xyz'}).subject

      b.glue(@user) { attribute :name }
      get_result(b)
    end.equivalent_to({ :user => 'xyz' })

    asserts "that it appends the glue attributes to result" do
      b = builder @user, {}

      b.glue(@user) { attribute :name => :user_name }
      get_result(b)
    end.equivalent_to({ :user_name => 'rabl' })

    asserts "that it does not generate new attributes if no glue attributes are present" do
      b = builder @user, {}
      mock(b).object_to_hash(@user,{ :root => false }).returns({}).subject

      b.glue(@user) { attribute :name }
      get_result(b)
    end.equals({})
  end

  context "#extend" do

    asserts "that it does not genereate if no data is present" do
      b = builder @user, {}
      mock(b).partial('users/show',{ :object => @user}).returns({}).subject

      b.extends('users/show') { attribute :name }
      get_result(b)
    end.equals({})

    asserts "that it generates if data is present" do
      b = builder @user, {}
      mock(b).partial('users/show',{ :object => @user}).returns({:user => 'xyz'}).subject

      b.extends('users/show') { attribute :name }
      get_result(b)
    end.equivalent_to({:user => 'xyz'})
  end

end
