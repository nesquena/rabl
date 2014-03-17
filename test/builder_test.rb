require File.expand_path('../teststrap',   __FILE__)

context "Rabl::Builder" do
  helper(:builder)    { |opt| Rabl::Builder.new(opt) }
  helper(:build_hash) { |obj, opt| builder(opt).build(obj) }

  setup do
    @users = [User.new, User.new]
    @user = User.new
    builder({:view_path => '/path/to/views'})
  end

  context "#initialize" do
    asserts_topic.assigns :options
    asserts_topic.assigns :_view_path
  end

  context "#build" do
    setup { b = builder({}); b.build(User.new); b }
    asserts_topic.assigns :_object
    asserts_topic.assigns :_result
  end

  context "#to_hash" do
    context "when given a simple object" do
      setup { builder({ :attributes => { :name => {} } }) }
      asserts "that the object is set properly" do
        topic.build(User.new, :root_name => "user")
      end.equivalent_to({ "user" => { :name => "rabl" } })
    end

    context "when given an object alias" do
     setup { builder({ :attributes => { :name => { :as => :foo } } }) }
      asserts "that the object is set properly" do
        topic.build(User.new, :root_name => "person")
      end.equivalent_to({ "person" => { :foo => "rabl" } })
    end

    context "when specified with no root" do
      setup { builder({ :attributes => { :name => { :as => :name } } }) }
      asserts "that the object is set properly" do
        topic.build(User.new, :root => false)
      end.equivalent_to({ :name => "rabl" })
    end

    context "when nil values are replaced with empty strings" do
      setup do
        Rabl.configuration.replace_nil_values_with_empty_strings = true
        builder({ :attributes => { :name => {} } })
      end
      asserts "that an empty string is returned as the value" do
        topic.build(User.new(:name => nil))
      end.equivalent_to({ :name => "" })
      teardown do
        Rabl.configuration.replace_nil_values_with_empty_strings = false
      end
    end

    context "when empty string values are replaced with nil values" do
      setup do
        Rabl.configuration.replace_empty_string_values_with_nil_values = true
        builder({ :attributes => { :name => {} } })
      end

      asserts "that nil is returned as the value" do
        topic.build(User.new(:name => ""))
      end.equivalent_to({ :name => nil })

      asserts "that it handles existing nil values correctly" do
        topic.build(User.new(:name => nil))
      end.equivalent_to({ :name => nil })

      asserts "that it handles existing non nil values correctly" do
        topic.build(User.new(:name => 10))
      end.equivalent_to({ :name => 10 })

      teardown do
        Rabl.configuration.replace_empty_string_values_with_nil_values = false
      end
    end

    context "when nil values are excluded" do
      setup do
        Rabl.configuration.exclude_nil_values = true
        builder({ :attributes => { :name => {} } })
      end
      asserts "that an nil attribute is not returned" do
        topic.build(User.new(:name => nil))
      end.equivalent_to({ })
      teardown do
        Rabl.configuration.exclude_nil_values = false
      end
    end
  end

  context "#attribute" do
    asserts "that the node" do
      build_hash @user, :attributes => { :name => {}, :city => { :as => :city } }
    end.equivalent_to({:name => 'rabl', :city => 'irvine'})

    context "that with a non-existent attribute" do
      context "when non-existent attributes are allowed by the configuration" do
        setup { stub(Rabl.configuration).raise_on_missing_attribute { false } }

        asserts "the node" do
          build_hash @user, :attributes => { :fake => :fake }
        end.equals({})
      end

      context "when non-existent attributes are forbidden by the configuration" do
        setup { stub(Rabl.configuration).raise_on_missing_attribute { true } }

        asserts "the node" do
          build_hash @user, :attributes => { :fake => :fake }
        end.raises(RuntimeError)
      end
    end
  end

  context "#node" do
    asserts "that it has node :foo" do
      build_hash @user, :node => [{ :name => :foo, :options => {}, :block => lambda { |u| "bar" } }]
    end.equivalent_to({:foo => 'bar'})

    asserts "that using object it has node :boo" do
      build_hash @user, :node => [
        { :name => :foo, :options => {}, :block => lambda { |u| "bar" } },
        { :name => :baz, :options => {}, :block => lambda { |u| u.city } }
      ]
    end.equivalent_to({:foo => 'bar', :baz => 'irvine'})
  end

  context "#child" do
    asserts "that it generates if no data present" do
      builder(:child => []).build(@user)
    end.equals({})

    asserts "that it generates with a hash" do
      b = builder(:child => [ { :data => { @user => :user }, :options => { }, :block => lambda { |u| attribute :name } } ])
      b.build(@user)
    end.equivalent_to({ :user => { :name => "rabl" } })

    asserts "that it generates with a hash alias" do
      b = builder :child => [{ :data => { @user => :person }, :options => {}, :block => lambda { |u| attribute :name } }]
      b.build(@user)
    end.equivalent_to({ :person => { :name => "rabl" } })

    asserts "that it generates with an object" do
      b = builder :child => [{ :data => @user, :options => {}, :block => lambda { |u| attribute :name } }]
      mock(b).data_name(@user) { :user }
      mock(b).object_to_hash(@user, { :root => false }).returns('xyz').subject
      b.build(@user)
    end.equivalent_to({ :user => 'xyz'})

    asserts "that it generates with an collection and child_root" do
      b = builder :child => [{ :data => @users, :options => {}, :block => lambda { |u| attribute :name } }], :child_root => true
      mock(b).data_name(@users) { :users }
      mock(b).object_to_hash(@users, { :root => true, :child_root => true }).returns('xyz').subject
      b.build(@user)
    end.equivalent_to({ :users => 'xyz'})

    asserts "that it generates with an collection and no child root" do
      b = builder :child => [{ :data => @users, :options => {}, :block => lambda { |u| attribute :name } }], :child_root => false
      mock(b).data_name(@users) { :users }
      mock(b).object_to_hash(@users, { :root => false, :child_root => false }).returns('xyz').subject
      b.build(@user)
    end.equivalent_to({ :users => 'xyz'})

    asserts "that it generates with an collection and a specified object_root_name and root" do
      ops = { :object_root => "person", :root => :people }
      b = builder :child => [{ :data => @users, :options => ops, :block => lambda { |u| attribute :name } }], :child_root => true
      mock(b).object_to_hash(@users, { :root => "person", :object_root_name => "person", :child_root => true }).returns('xyz').subject
      b.build(@user)
    end.equivalent_to({ :people => 'xyz'})
  end

  context "#glue" do
    asserts "that it generates if no data present" do
      builder(:glue => []).build(@user)
    end.equals({})

    asserts "that it generates the glue attributes" do
      b = builder :glue => [{ :data => @user, :options => {}, :block => lambda { |u| attribute :name }}]
      mock(b).object_to_hash(@user, { :root => false }).returns({:user => 'xyz'}).subject
      b.build(@user)
    end.equivalent_to({ :user => 'xyz' })

    asserts "that it appends the glue attributes to result" do
      b = builder :glue => [{ :data => @user, :options => {}, :block => lambda { |u| attribute :name => :user_name }}]
      b.build(@user)
    end.equivalent_to({ :user_name => 'rabl' })

    asserts "that it does not generate new attributes if no glue attributes are present" do
      b = builder :glue => [{ :data => @user, :options => {}, :block => lambda { |u| attribute :name }}]
      mock(b).object_to_hash(@user,{ :root => false }).returns({}).subject
      b.build(@user)
    end.equals({})
  end

  context "#extend" do
    asserts "that it does not genereate if no data is present" do
      b = builder :extends => [{ :file => 'users/show', :options => {}, :block => lambda { |u| attribute :name  }}]
      mock(b).partial('users/show',{ :object => @user }).returns({}).subject
      b.build(@user)
    end.equals({})

    asserts "that it generates if data is present" do
      b = builder :extends => [{ :file => 'users/show', :options => {}, :block => lambda { |u| attribute :name  }}]
      mock(b).partial('users/show', { :object => @user }).returns({:user => 'xyz'}).subject
      b.build(@user)
    end.equivalent_to({:user => 'xyz'})

    asserts "that it generates if local data is present but object is false" do
      b = builder :extends => [{ :file => 'users/show', :options => { :object => @user }, :block => lambda { |u| attribute :name  }}]
      mock(b).partial('users/show', { :object => @user }).returns({:user => 'xyz'}).subject
      b.build(false)
    end.equivalent_to({:user => 'xyz'})
  end

  context "#resolve_conditionals" do
    class ArbObj
      def cool?
        false
      end

      def smooth?
        true
      end
    end

    asserts "that it can use symbols on if condition and return false if method returns false" do
      scope = Rabl::Builder.new
      scope.instance_variable_set(:@_object, ArbObj.new)
      scope.send(:resolve_condition, { :if => :cool? })
    end.equals(false)

    asserts "that it can use symbols on if condition and return true if method returns true" do
      scope = Rabl::Builder.new
      scope.instance_variable_set(:@_object, ArbObj.new)
      scope.send :resolve_condition, { :if => :smooth? }
    end.equals(true)

    asserts "that it can use symbols as unless condition and return true if method returns false" do
      scope = Rabl::Builder.new
      scope.instance_variable_set(:@_object, ArbObj.new)
      scope.send :resolve_condition, { :unless => :cool? }
    end.equals(true)

    asserts "that it can use symbols as unmless condition and return false if method returns true" do
      scope = Rabl::Builder.new
      scope.instance_variable_set(:@_object, ArbObj.new)
      scope.send :resolve_condition, { :unless => :smooth? }
    end.equals(false)
  end
end
