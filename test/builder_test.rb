# frozen_string_literal: true

require 'active_support/core_ext/string/output_safety' # SafeBuffer, for a key's name changed later
require File.expand_path('../teststrap',   __FILE__)

context "Rabl::Builder" do
  helper(:builder)    { |*args| Rabl::Builder.new(*args) }
  helper(:build_hash) { |*args| builder(*args).to_hash }

  setup do
    @users = [User.new, User.new]
    @user = User.new
    builder(nil, nil, {:view_path => '/path/to/views'})
  end

  context "#initialize" do
    asserts_topic.assigns :options
    asserts_topic.assigns :_view_path
  end

  context "#to_hash" do
    context "when given a simple object" do
      setup { builder(nil, { :attributes => [ { :name => :name } ] }) }
      asserts "that the object is set properly" do
        topic.to_hash(User.new, nil, :root_name => "user")
      end.equivalent_to({ "user" => { :name => "rabl" } })
    end

    context "when given an object alias" do
     setup { builder(nil, { :attributes => [ { :name => :name, :options => { :as => :foo } } ] }) }
      asserts "that the object is set properly" do
        topic.to_hash(User.new, nil, :root_name => "person")
      end.equivalent_to({ "person" => { :foo => "rabl" } })
    end

    context "when specified with no root" do
      setup { builder(nil, { :attributes => [ { :name => :name, :options => { :as => :name } } ] }) }
      asserts "that the object is set properly" do
        topic.to_hash(User.new, nil, :root => false)
      end.equivalent_to({ :name => "rabl" })
    end

    context "when nil values are replaced with empty strings" do
      setup do
        Rabl.configuration.replace_nil_values_with_empty_strings = true
        builder(nil, { :attributes => [ { :name => :name } ], :node => [{ :name => :extra, :options => {}, :block => lambda { |u| { :twitter => u.twitter } } }] })
      end

      asserts "that an empty string is returned as the value" do
        topic.to_hash(User.new(:name => nil, :twitter => nil))
      end.equivalent_to({ :name => '', :extra => { :twitter => '' } })

      asserts "that it handles existing non nil values correctly" do
        topic.to_hash(User.new(:name => 10, :twitter => 'twitter'))
      end.equivalent_to({ :name => 10, :extra => { :twitter => 'twitter' } })

      teardown do
        Rabl.configuration.replace_nil_values_with_empty_strings = false
      end
    end

    context "when empty string values are replaced with nil values" do
      setup do
        Rabl.configuration.replace_empty_string_values_with_nil_values = true
        builder(nil, { :attributes => [ { :name => :name } ], :node => [{ :name => :extra, :options => {}, :block => lambda { |u| { :twitter => u.twitter } } }] })
      end

      asserts "that nil is returned as the value" do
        topic.to_hash(User.new(:name => "", :twitter => ''))
      end.equivalent_to({ :name => nil, :extra => { :twitter => nil } })

      asserts "that it handles existing nil values correctly" do
        topic.to_hash(User.new(:name => nil, :twitter => nil))
      end.equivalent_to({ :name => nil, :extra => { :twitter => nil } })

      asserts "that it handles existing non nil values correctly" do
        topic.to_hash(User.new(:name => 10, :twitter => 'twitter'))
      end.equivalent_to({ :name => 10, :extra => { :twitter => 'twitter' } })

      teardown do
        Rabl.configuration.replace_empty_string_values_with_nil_values = false
      end
    end

    context "when nil values are excluded" do
      setup do
        Rabl.configuration.exclude_nil_values = true
        builder(nil, { :attributes => [ { :name => :name } ] })
      end
      asserts "that an nil attribute is not returned" do
        topic.to_hash(User.new(:name => nil))
      end.equivalent_to({ })
      teardown do
        Rabl.configuration.exclude_nil_values = false
      end
    end

    context "when keys are camelized" do
      setup do
        Rabl.configuration.camelize_keys = true
        builder(nil, { :attributes => [ { :name => :first_pets_name } ] })
      end
      asserts "that the key is camelized" do
        topic.to_hash(User.new)
      end.equivalent_to({ :firstPetsName => 'jack' })
      teardown do
        Rabl.configuration.camelize_keys = false
      end
    end

    context "when keys are camelized with upper case first letter" do
      setup do
        Rabl.configuration.camelize_keys = :upper
        builder(nil, { :attributes => [ { :name => :first_pets_name } ] })
      end
      asserts "that the key is camelized with upper case first letter" do
        topic.to_hash(User.new)
      end.equivalent_to({ :FirstPetsName => 'jack' })
      teardown do
        Rabl.configuration.camelize_keys = false
      end
    end
  end

  context "when a key's name is camelized more than once" do
    setup do
      Rabl.configuration.camelize_keys = :lower
      # an empty map makes the first render in the frozen-copy test store the name it is given;
      # the rehash there is what keeps that test honest about a name changed in place
      Rabl.configuration.instance_variable_get(:@camelized_keys).each_value(&:clear)
      @render = lambda do |name|
        Rabl::Renderer.new("object false\nnode(locals[:name]) { 1 }", nil,
                           :format => "hash", :locals => { :name => name }).render
      end
    end

    teardown do
      Rabl.configuration.camelize_keys = false
    end

    # a Hash keeps an unfrozen String subclass as it is, so a name changed in place must not
    # reach the value remembered for it
    asserts("a name changed after the render doesn't answer the new name") do
      name = "first_name".html_safe
      first = @render.call(name)
      name << "_extra"
      Rabl.configuration.instance_variable_get(:@camelized_keys)[false].rehash
      [first, @render.call("first_name_extra")]
    end.equals [{ :firstName => 1 }, { :firstNameExtra => 1 }]

    asserts("a name longer than the limit is camelized each time, and not kept") do
      long = "x" * (Rabl::Configuration::CAMELIZED_KEY_LENGTH_LIMIT + 1) + "_name"
      camelized = Rabl.configuration.camelized_key(long, false)
      remembered = Rabl.configuration.instance_variable_get(:@camelized_keys)[false]
      [camelized == long.camelize(:lower).to_sym, remembered.key?(Rabl.frozen_copy(long))]
    end.equals [true, false]

    # the limit is a byte count, so a name that fits in characters but not in bytes is not kept
    asserts("a name under the limit in characters and over it in bytes is not kept either") do
      long = "é" * (Rabl::Configuration::CAMELIZED_KEY_LENGTH_LIMIT / 2 + 1)
      camelized = Rabl.configuration.camelized_key(long, false)
      remembered = Rabl.configuration.instance_variable_get(:@camelized_keys)[false]
      [camelized == long.camelize(:lower).to_sym, remembered.key?(Rabl.frozen_copy(long))]
    end.equals [true, false]

    asserts("a full map is emptied when a new name arrives") do
      config = Rabl.configuration
      config.instance_variable_get(:@camelized_keys)[false].clear
      config.define_singleton_method(:camelized_keys_limit) { 2 }
      begin
        names = (1..3).map { |i| config.camelized_key("kept_#{i}", false) }
        [names, config.instance_variable_get(:@camelized_keys)[false].size]
      ensure
        config.singleton_class.send(:remove_method, :camelized_keys_limit)
      end
    end.equals [[:kept1, :kept2, :kept3], 1]

    # a name the map holds is answered from it, without camelizing it again: a Symbol name costs
    # one String for `to_s` on every call that misses the map
    asserts("a name the map holds is answered without allocating for it") do
      config = Rabl.configuration
      config.camelized_key(:seen_name, false)
      GC.disable
      before = GC.stat(:total_allocated_objects)
      1000.times { config.camelized_key(:seen_name, false) }
      allocated = GC.stat(:total_allocated_objects) - before
      GC.enable
      allocated < 100
    end.equals true

    # the limit is a maximum, so a name of exactly that many bytes is kept
    asserts("a name of exactly the limit in bytes is kept") do
      name = "x" * Rabl::Configuration::CAMELIZED_KEY_LENGTH_LIMIT
      Rabl.configuration.camelized_key(name, false)
      Rabl.configuration.instance_variable_get(:@camelized_keys)[false].key?(Rabl.frozen_copy(name))
    end.equals true
  end

  context "#attribute" do
    asserts "that the node" do
      build_hash @user, :attributes => [ { :name => :name }, { :name => :city, :options => { :as => :city } } ]
    end.equivalent_to({:name => 'rabl', :city => 'irvine'})

    context "that with a non-existent attribute" do
      context "when non-existent attributes are allowed by the configuration" do
        setup { stub(Rabl.configuration).raise_on_missing_attribute { false } }

        asserts "the node" do
          build_hash @user, :attributes => [ { :name => :fake } ]
        end.equals({})
      end

      context "when non-existent attributes are forbidden by the configuration" do
        setup { stub(Rabl.configuration).raise_on_missing_attribute { true } }

        asserts "the node" do
          build_hash @user, :attributes => [ { :name => :fake } ]
        end.raises(RuntimeError)
      end
    end

    context "that with a string key" do
      setup { builder(nil, { :attributes => [ { :name => "name" } ] }) }
      asserts "the node name is converted to a symbol" do
        topic.to_hash(User.new, :name => "user")
      end.equivalent_to({ :name => "rabl" })
    end

    context "that with the same node names as strings and symbols" do
      setup { builder(nil, { :attributes => [ { :name => "name" }, { :name => :name } ] }) }
      asserts "the nodes aren't duplicated" do
        topic.to_hash(User.new, :name => "user")
      end.equivalent_to({ :name => "rabl" })
    end
  end

  context "#node" do
    asserts "that it has node :foo" do
      build_hash @user, :node => [{ :name => :foo, :options => {}, :block => lambda { |u| "bar" } }]
    end.equivalent_to({:foo => 'bar'})

    asserts "that it excludes nodes in the :except list" do
      build_hash @user, {:node => [{ :name => :foo, :block => lambda { |u| "bar" } }]}, {except: [:foo]}
    end.equivalent_to({})

    asserts "that it excludes nodes in the :except attribute" do
      build_hash @user, {:node => [{ :name => :foo, :block => lambda { |u| "bar" } }]}, {except: :foo}
    end.equivalent_to({})

    asserts "that it has node not in except list" do
      build_hash @user, {:node => [{ :name => :foo, :block => lambda { |u| "bar" } }]}, {except: [:unknown]}
    end.equivalent_to({:foo => 'bar'})

    asserts "that it has multiple nodes" do
      build_hash(@user,
                 {:node => [{ :name => :foo, :block => lambda { |u| "bar" } },
                            {:name => :baz, :block => lambda{|_u| "bar"}},
                            {:name => :bam, :block => lambda{|_u| "boom"}}]},
                  {except: [:unknown, :baz]})
    end.equivalent_to({:foo => 'bar', :bam => 'boom'})

    asserts "that using object it has node :boo" do
      build_hash @user, :node => [
        { :name => :foo, :options => {}, :block => lambda { |u| "bar" } },
        { :name => :baz, :options => {}, :block => lambda { |u| u.city } }
      ]
    end.equivalent_to({:foo => 'bar', :baz => 'irvine'})

    asserts "that it converts the node name to a symbol" do
      build_hash @user, :node => [{ :name => "foo", :options => {}, :block => lambda { |u| "bar" } }]
    end.equivalent_to({:foo => 'bar'})

    asserts "that the same node names as a string and symbol aren't duplicated" do
      build_hash @user, :node => [
        { :name => "foo", :options => {}, :block => lambda { |u| "bar" } },
        { :name => :foo, :options => {}, :block => lambda { |u| "bar" } }
      ]
    end.equivalent_to({:foo => 'bar'})
  end

  context "#child" do
    asserts "that it generates if no data present" do
      builder(nil, :child => []).to_hash(@user)
    end.equals({})

    asserts "that it generates with a hash" do
      b = builder(nil, :child => [ { :data => { @user => :user }, :options => { }, :block => lambda { |u| attribute :name } } ])
      b.to_hash(@user)
    end.equivalent_to({ :user => { :name => "rabl" } })

    asserts "that it generates with a hash alias" do
      b = builder nil, :child => [{ :data => { @user => :person }, :options => {}, :block => lambda { |u| attribute :name } }]
      b.to_hash(@user)
    end.equivalent_to({ :person => { :name => "rabl" } })

    asserts "that it generates with an object" do
      b = builder nil, :child => [{ :data => @user, :options => {}, :block => lambda { |u| attribute :name } }]
      e = Rabl::Engine.new('')
      mock(b).data_name(@user) { :user }
      mock(e).render.returns('xyz')
      mock(b).object_to_engine(@user, { :root => false }).returns(e).subject
      b.to_hash(@user)
    end.equivalent_to({ :user => 'xyz'})

    asserts "that it generates with an collection and child_root" do
      b = builder nil, { :child => [{ :data => @users, :options => {}, :block => lambda { |u| attribute :name } }] }, { :child_root => true }
      e = Rabl::Engine.new('')
      mock(b).data_name(@users) { :users }
      mock(e).render.returns('xyz')
      mock(b).object_to_engine(@users, { :root => true, :child_root => true }).returns(e).subject
      b.to_hash(@user)
    end.equivalent_to({ :users => 'xyz'})

    asserts "that it generates with an collection and no child root" do
      b = builder nil, { :child => [{ :data => @users, :options => {}, :block => lambda { |u| attribute :name } }] }, { :child_root => false }
      e = Rabl::Engine.new('')
      mock(b).data_name(@users) { :users }
      mock(e).render.returns('xyz')
      mock(b).object_to_engine(@users, { :root => false, :child_root => false }).returns(e).subject
      b.to_hash(@user)
    end.equivalent_to({ :users => 'xyz'})

    asserts "that it generates with an collection and a specified object_root_name and root" do
      ops = { :object_root => "person", :root => :people }
      b = builder nil, { :child => [{ :data => @users, :options => ops, :block => lambda { |u| attribute :name } }] }, { :child_root => true }
      e = Rabl::Engine.new('')
      mock(e).render.returns('xyz')
      mock(b).object_to_engine(@users, { :root => "person", :object_root_name => "person", :child_root => true }).returns(e).subject
      b.to_hash(@user)
    end.equivalent_to({ :people => 'xyz'})

    asserts "that it converts the child name to a symbol" do
      b = builder(nil, :child => [ { :data => { @user => "user" }, :options => { }, :block => lambda { |u| attribute :name } } ])
      b.to_hash(@user)
    end.equivalent_to({ :user => { :name => "rabl" } })

    asserts "that it doesn't duplicate children with the same name as a string and symbol" do
      b = builder(nil, :child => [
        { :data => { @user => "user" }, :options => { }, :block => lambda { |u| attribute :name } },
        { :data => { @user => :user }, :options => { }, :block => lambda { |u| attribute :name } }
      ])
      b.to_hash(@user)
    end.equivalent_to({ :user => { :name => "rabl" } })
  end

  context "#glue" do
    asserts "that it generates if no data present" do
      builder(nil, :glue => []).to_hash(@user)
    end.equals({})

    asserts "that it generates the glue attributes" do
      b = builder nil, :glue => [{ :data => @user, :options => {}, :block => lambda { |u| attribute :name }}]
      e = Rabl::Engine.new('')
      mock(e).render.returns({:user => 'xyz'})
      mock(b).object_to_engine(@user, :root => false).returns(e).subject
      b.to_hash(@user)
    end.equivalent_to({ :user => 'xyz' })

    asserts "that it appends the glue attributes to result" do
      b = builder nil, :glue => [{ :data => @user, :options => {}, :block => lambda { |u| attribute :name => :user_name }}]
      b.to_hash(@user)
    end.equivalent_to({ :user_name => 'rabl' })

    asserts "that it does not generate new attributes if no glue attributes are present" do
      b = builder nil, :glue => [{ :data => @user, :options => {}, :block => lambda { |u| attribute :name }}]
      e = Rabl::Engine.new('')
      mock(e).render.returns({})
      mock(b).object_to_engine(@user, :root => false).returns(e).subject
      b.to_hash(@user)
    end.equals({})
  end

  context "#extends" do
    asserts "that it does not generate if no data is present" do
      b = builder nil, :extends => [{ :file => 'users/show', :options => {}, :block => lambda { |u| attribute :name  }}]
      e = Rabl::Engine.new('users/show')
      mock(b).partial_as_engine('users/show',{ :object => @user}).returns(e)
      mock(e).render.returns({}).subject
      b.to_hash(@user)
    end.equals({})

    asserts "that it generates if data is present" do
      b = builder nil, :extends => [{ :file => 'users/show', :options => {}, :block => lambda { |u| attribute :name  }}]
      e = Rabl::Engine.new('users/show')
      mock(b).partial_as_engine('users/show',{ :object => @user}).returns(e)
      mock(e).render.returns({:user => 'xyz'}).subject
      b.to_hash(@user)
    end.equivalent_to({:user => 'xyz'})

    asserts "that it generates if local data is present but object is false" do
      b = builder nil, :extends => [{ :file => 'users/show', :options => { :object => @user }, :block => lambda { |u| attribute :name  }}]
      e = Rabl::Engine.new('users/show')
      mock(b).partial_as_engine('users/show',{ :object => @user}).returns(e)
      mock(e).render.returns({:user => 'xyz'}).subject
      b.to_hash(false)
    end.equivalent_to({:user => 'xyz'})

    asserts "that it generates with exclude 'except' option" do
      b = builder nil, :extends => [{ :file => 'users/show', :options => { :except => :user_id }, :block => lambda { |u| attribute :name  }}]
      e = Rabl::Engine.new('users/show')
      mock(b).partial_as_engine('users/show',{ :object => @user, except: :user_id}).returns(e)
      mock(e).render.returns({:user => 'xyz'}).subject
      b.to_hash(@user)
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
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send(:resolve_condition, { :if => :cool? })
    end.equals(false)

    asserts "that it can use symbols on if condition and return true if method returns true" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send :resolve_condition, { :if => :smooth? }
    end.equals(true)

    asserts "that it can use symbols as unless condition and return true if method returns false" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send :resolve_condition, { :unless => :cool? }
    end.equals(true)

    asserts "that it can use symbols as unless condition and return false if method returns true" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send :resolve_condition, { :unless => :smooth? }
    end.equals(false)

    asserts "that it can use :unless and :if at the same time and return true when if is true and unless is false" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send :resolve_condition, { :if => true, :unless => false }
    end.equals(true)

    asserts "that it can use :unless and :if at the same time and return false when if is false and unless is false" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send :resolve_condition, { :if => false, :unless => false }
    end.equals(false)

    asserts "that it can use :unless and :if at the same time and return false when if is true and unless is true" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send :resolve_condition, { :if => true, :unless => true }
    end.equals(false)

    asserts "that it can use :unless and :if at the same time and return false when if is false and unless is true" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send :resolve_condition, { :if => false, :unless => true }
    end.equals(false)

    asserts "that it can use lambda on if condition and return false if lambda returns false" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send(:resolve_condition, { :if => lambda { |obj| false } })
    end.equals(false)

    asserts "that it can use lambda on if condition and return true if lambda returns true" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send(:resolve_condition, { :if => lambda { |obj| true } })
    end.equals(true)

    asserts "that it can use proc on if condition and return false if proc returns false" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send(:resolve_condition, { :if => proc { false } })
    end.equals(false)

    asserts "that it can use proc on if condition and return true if proc returns true" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send(:resolve_condition, { :if => proc { true } })
    end.equals(true)

    asserts "that it can use a variable on if condition and return true if variable is truthy" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send(:resolve_condition, { :if => 'Im truthy' })
    end.equals('Im truthy')

    asserts "that it can use a variable on if condition and return false if variable is falsy" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send(:resolve_condition, { :if => nil })
    end.equals(nil)

    asserts "that it can use a hash variable on if condition and return true" do
      scope = Rabl::Builder.new(ArbObj.new)
      scope.send(:resolve_condition, { :if => { some: 'data' } })
    end.equals({some: 'data'})
  end
end
