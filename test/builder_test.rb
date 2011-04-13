require File.expand_path('../teststrap',   __FILE__)
require File.expand_path('../models/user', __FILE__)

context "Rabl::Builder" do

  helper(:builder)    { |obj,opt| Rabl::Builder.new obj, opt        }
  helper(:get_result) { |obj| obj.instance_variable_get("@_result") }

  setup do
    @user = User.new
    builder User.new, {}
  end

  context "#initialize" do
    asserts_topic.assigns :_object
    asserts_topic.assigns :options
    asserts_topic.assigns :_result
  end

  context "#attribute" do

    context "when given an array" do

      asserts "that the node" do
        topic.attribute :name, :city
        get_result(topic)
      end.equivalent_to({:name => 'rabl', :city => 'irvine'})

      denies "that with a non-existent attribute the node" do
        topic.attribute :fake
        get_result(topic)[:fake]
      end.exists

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
      engine = mock!.object_to_hash(@user,nil).returns('xyz').subject
      b = builder @user, { :engine => engine }

      b.child(@user => :user) { attribute :name }
      get_result(b)
    end.equivalent_to({ :user => 'xyz'})

    asserts "that it generates with an object" do
      engine = mock!.object_to_hash(@user,nil).returns('xyz').subject
      mock(engine).model_name(@user) { :user }
      b = builder @user, { :engine => engine }

      b.child(@user) { attribute :name }
      get_result(b)
    end.equivalent_to({ :user => 'xyz'})
  end

  context "#glue" do

    denies "that it generates if no data present" do
      topic.glue nil
    end

    asserts "that it generates the glue attributes" do
      engine = mock!.object_to_hash(@user, nil).returns({:user => 'xyz'}).subject
      b = builder @user, { :engine => engine }

      b.glue(@user) { attribute :name }
      get_result(b)
    end.equivalent_to({ :user => 'xyz' })

    asserts "that it does not generate new attributes if no glue attributes are present" do
      engine = mock!.object_to_hash(@user, nil).returns({}).subject
      b = builder @user, { :engine => engine }

      b.glue(@user) { attribute :name }
      get_result(b)
    end.equals({})
  end

  context "#extend" do

    asserts "that it does not genereate if no data is present" do
      engine = mock!.partial('users/show',{ :object => @user}).returns({}).subject
      b = builder @user, { :engine => engine }

      b.extends('users/show') { attribute :name }
      get_result(b)
    end.equals({})

    asserts "that it generates if data is present" do
      engine = mock!.partial('users/show',{ :object => @user}).returns({:user => 'xyz'}).subject
      b = builder @user, { :engine => engine }

      b.extends('users/show') { attribute :name }
      get_result(b)
    end.equivalent_to({:user => 'xyz'})
  end

end
