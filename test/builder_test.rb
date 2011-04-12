require File.expand_path('../teststrap',__FILE__)

context "Rabl::Builder" do

  helper(:builder)    { |obj,opt| Rabl::Builder.new obj, opt        }
  helper(:get_result) { |obj| obj.instance_variable_get("@_result") }

  context "#initialize" do
    setup { builder Object.new, {:a => 1 } }
    asserts_topic.assigns :_object
    asserts_topic.assigns :options
    asserts_topic.assigns :_result
  end

  context "#attribute" do

    context "when given an array" do
      setup do
        obj = mock!.name.returns('name').subject
        mock(obj).address { 'address' }
        builder obj, {}
      end

      asserts "that the node" do
        topic.attribute :name, :address
        get_result(topic)
      end.equivalent_to({:name => 'name', :address => 'address'})

      denies "that with a non-existent attribute the node" do
        topic.attribute :fake
        get_result(topic)[:fake]
      end.exists

    end

    context "when given a Hash" do

      asserts "that using :as, the node" do
        obj = mock!.city.returns('city').subject
        b = builder obj, {}

        b.attribute :city, :as => 'foo'
        get_result(b)
      end.equals({'foo'=>'city'})

      asserts "with multiple attributes, the node" do
        obj = mock!.foo.returns('foo').subject
        mock(obj).bar { 'bar' }
        b = builder obj, {}

        b.attributes :foo => :a, :bar => :b
        get_result(b)
      end.equivalent_to({:a => 'foo', :b => 'bar'})

    end

  end

  context "#code" do

    asserts "that it has node :foo" do
      b = builder Object.new, {}
      b.code(:foo) { "bar" }
      get_result(b)[:foo]
    end.equals 'bar'

    asserts "that using object it has node :boo" do
      obj = mock!.boo.returns('baz').subject
      b = builder obj, {}
      b.code(:baz) { |u| u.boo }
      get_result(b)[:baz]
    end.equals 'baz'
  end

end
