require 'json'
require File.expand_path('../teststrap', __FILE__)
require 'rabl/template'
require File.expand_path('../models/ormless', __FILE__)

context "Rabl::Engine" do
  helper(:rabl) { |t| RablTemplate.new { t } }
  # context_scope 'users', [@user]
  helper(:context_scope) { |name, value|
    scope = Object.new
    stub(scope).controller { stub(Object).controller_name { name } }
    scope.instance_variable_set :"@#{name}", value
    scope
  }

  context "#initialize" do
    setup do
      Rabl::Engine.new("...source...", { :format => 'xml', :root => true, :view_path => '/path/to/views' })
    end

    asserts_topic.assigns :_source
    asserts_topic.assigns :_options
    asserts_topic.assigns :_view_path
  end

  context "#cache" do
    context "with cache" do
      setup do
        template = rabl %q{
          cache 'foo'
        }
        template.render(Object.new)
        template.instance_eval('@engine')
      end

      asserts_topic.assigns(:_cache) { ['foo', nil] }
    end

    context "with cache and options" do
      setup do
        template = rabl %q{
          cache 'foo', :expires_in => 'bar'
        }
        template.render(Object.new)
        template.instance_eval('@engine')
      end

      asserts_topic.assigns(:_cache) { ['foo', { :expires_in => 'bar' }] }
    end

    context "without cache" do
      setup do
        template = RablTemplate.new {}
        template.render(Object.new)
        template.instance_eval('@engine')
      end

      denies(:instance_variable_defined?, :@_cache)
    end
  end

  context "with defaults" do
    setup do
      Rabl.configure do |config|
        config.include_json_root     = true
        config.include_xml_root      = false
        config.enable_json_callbacks = false
      end
    end

    context "#cache" do
      asserts "does not modify output" do
        template = rabl %q{
          object @user
          cache @user
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.matches "{\"user\":{}}"
    end

    context "#object" do
      asserts "that it sets data source" do
        template = rabl %q{
          object @user
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.matches "{\"user\":{}}"

      asserts "that it can set root node" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals "{\"person\":{}}"

      asserts "that it can set root node with a nil object and explicit name" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, nil
        template.render(scope)
      end.equals "{\"person\":{}}"

      asserts "that it can use non-ORM objects" do
        template = rabl %q{
          object @other
        }
        scope = Object.new
        scope.instance_variable_set :@other, Ormless.new
        template.render(scope)
      end.equals "{\"ormless\":{}}"

      asserts "that it works with nested controllers" do
        template = rabl ""
        scope = NestedScope::User.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.matches "{}"
    end

    context "#collection" do
       asserts "that it sets object to be blank array" do
          template = rabl %{
            collection []
          }
          scope = Object.new
          template.render(scope)
        end.equals "[]"

      asserts "that it sets object to be casted as a simple array" do
        template = rabl %{
          collection @users
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "[{\"user\":{}},{\"user\":{}}]"

      asserts "that it sets root node for objects" do
        template = rabl %{
          collection @users => :people
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "{\"people\":[{\"person\":{}},{\"person\":{}}]}"

      asserts "that it doesn't set root node for objects when specified" do
       template = rabl %{
         collection @users, :root => :people, :object_root => false
       }
       scope = Object.new
       scope.instance_variable_set :@users, [User.new, User.new]
       template.render(scope)
      end.equals "{\"people\":[{},{}]}"

      asserts "that it sets proper object and root names when specified" do
       template = rabl %{
         collection @users, :root => :people, :object_root => :user
       }
       scope = Object.new
       scope.instance_variable_set :@users, [User.new, User.new]
       template.render(scope)
      end.equals "{\"people\":[{\"user\":{}},{\"user\":{}}]}"

      asserts "that it can use non-ORM objects" do
        template = rabl %q{
          object @others
        }
        scope = Object.new
        scope.instance_variable_set :@others, [Ormless.new, Ormless.new]
        template.render(scope)
      end.equals "[{\"ormless\":{}},{\"ormless\":{}}]"
    end

    context "#attribute" do
      asserts "that it adds an attribute or method to be included in output" do
        template = rabl %{
          object @user
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"user\":{\"name\":\"irvine\"}}")

      asserts "that it can add attribute under a different key name through :as" do
        template = rabl %{
          object @user
          attribute :name, :as => 'city'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"user\":{\"city\":\"irvine\"}}")

      asserts "that it can add attribute under a different key name through hash" do
        template = rabl %{
          object @user
          attribute :name => :city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"user\":{\"city\":\"irvine\"}}")
    end

    context "#code" do
      asserts "that it can create an arbitraty code node" do
        template = rabl %{
          code(:foo) { 'bar' }
        }
        template.render(Object.new)
      end.equals "{\"foo\":\"bar\"}"

      asserts "that it can be passed conditionals" do
        template = rabl %{
          code(:foo, :if => lambda { |i| false }) { 'bar' }
        }
        template.render(Object.new)
      end.equals "{}"

      asserts "that it can merge the result with a collection element given no name" do
        template = rabl %{
          collection @users
          code do |user|
            {:name => user.name}
          end
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'a'), User.new(:name => 'b')]
        JSON.parse(template.render(scope))
      end.equals JSON.parse("[{\"user\":{\"name\":\"a\"}},{\"user\":{\"name\":\"b\"}}]")

      asserts "that it can merge the result on a child node given no name" do
        template = rabl %{
          object @user
          attribute :name
          child(@user) do
            code do |user|
              {:city => user.city}
            end
          end
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"user\":{\"name\":\"leo\",\"user\":{\"city\":\"LA\"}}}")
    end

    context "#child" do
      asserts "that it can create a child node" do
        template = rabl %{
          object @user
          attribute :name
          child(@user) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"user\":{\"name\":\"leo\",\"user\":{\"city\":\"LA\"}}}")

      asserts "that it can create a child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(@user => :person) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"user\":{\"name\":\"leo\",\"person\":{\"city\":\"LA\"}}}")

      asserts "that it passes the data object to the block" do
        template = rabl %{
          object @user
          child(@user => :person) do |user|
            attribute :name if user.name == 'leo'
          end
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo')
        template.render(scope)
      end.equals "{\"user\":{\"person\":{\"name\":\"leo\"}}}"

      asserts "it sets root node for child collection" do
        template = rabl %{
          object @user
          attribute :name
          child(@users) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        scope.instance_variable_set :@users, [User.new(:name => 'one', :city => 'UNO'), User.new(:name => 'two', :city => 'DOS')]
        template.render(scope)
      end.equals "{\"user\":{\"name\":\"leo\",\"users\":[{\"user\":{\"city\":\"UNO\"}},{\"user\":{\"city\":\"DOS\"}}]}}"

      asserts "child chooses name based on symbol if no elements" do
        template = rabl %{
          object @bar => :bar
          child(:foos) { attribute :city }
        }
        scope = Object.new
        bar = Object.new
        stub(bar).foos { [] }
        scope.instance_variable_set :@bar, bar
        template.render(scope)
      end.equals "{\"bar\":{\"foos\":[]}}"

      asserts "it allows suppression of root node for child collection" do
        template = rabl %{
          object @user
          attribute :name
          child(@users, :object_root => false) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        scope.instance_variable_set :@users, [User.new(:name => 'one', :city => 'UNO'), User.new(:name => 'two', :city => 'DOS')]
        template.render(scope)
      end.equals "{\"user\":{\"name\":\"leo\",\"users\":[{\"city\":\"UNO\"},{\"city\":\"DOS\"}]}}"

      asserts "it allows modification of object root node for child collection" do
        template = rabl %{
          object @user
          attribute :name
          child(@users, :object_root => 'person') { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        scope.instance_variable_set :@users, [User.new(:name => 'one', :city => 'UNO'), User.new(:name => 'two', :city => 'DOS')]
        template.render(scope)
      end.equals "{\"user\":{\"name\":\"leo\",\"users\":[{\"person\":{\"city\":\"UNO\"}},{\"person\":{\"city\":\"DOS\"}}]}}"

      asserts "it allows modification of both labels for a child collection" do
        template = rabl %{
          object @user
          attribute :name
          child(@users, :root => "people", :object_root => 'item') { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        scope.instance_variable_set :@users, [User.new(:name => 'one', :city => 'UNO'), User.new(:name => 'two', :city => 'DOS')]
        template.render(scope)
      end.equals "{\"user\":{\"name\":\"leo\",\"people\":[{\"item\":{\"city\":\"UNO\"}},{\"item\":{\"city\":\"DOS\"}}]}}"
    end

    context "#glue" do
      asserts "that it glues data from a child node" do
        template = rabl %{
          object @user
          attribute :name
          glue(@user) { attribute :city }
          glue(@user) { attribute :age  }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA', :age => 12)
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"user\":{\"name\":\"leo\",\"city\":\"LA\",\"age\":12}}")

      asserts "that it passes the data object to the block" do
        template = rabl %{
          object @user
          glue(@user) {|user| attribute :age if user.name == 'leo' }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :age => 12)
        template.render(scope)
      end.equals "{\"user\":{\"age\":12}}"
    end

    context "#partial" do
      asserts "that it creates object from partial and passes local" do
        template = rabl %{
         object false
         node :foo do
           partial("foo/bar", :object => @user, :locals => { :foo => "bar" })
         end
        }
        scope = Object.new
        @user = User.new(:name => 'leo', :city => 'LA', :age => 12)
        scope.instance_variable_set :@user, @user
        any_instance_of(Rabl::Engine) do |b|
          mock(b).fetch_source("foo/bar", :view_path => nil).once
          mock(b).object_to_hash(@user, :locals => { :foo => "bar" }, :source => nil, :source_location => nil, :template => 'foo/bar').returns({ :name => 'leo', :city => 'LA', :age => 12 })
        end
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{ \"foo\" : {\"name\":\"leo\",\"city\":\"LA\",\"age\":12} }")
    end

    teardown do
      Rabl.reset_configuration!
    end
  end # with json root

  context "without json root" do
    setup do
      Rabl.configure do |config|
        config.include_json_root     = false
        config.include_xml_root      = false
        config.enable_json_callbacks = false
      end
    end

    context "#object" do
      asserts "that it sets default object" do
        template = rabl %{
          attribute :name
        }
        scope = context_scope('user', User.new)
        template.render(scope).split
      end.equals "{\"name\":\"rabl\"}".split

      asserts "that it does not set a collection as default object" do
        template = rabl %{
          attribute :name
        }
        scope = context_scope('user', [])
        template.render(scope).split
      end.equals "{}".split

      asserts "that it sets data source" do
        template = rabl %q{
          object @user
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.matches "{}"

      asserts "that it can set root node" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals "{}"

      asserts "that it can set root node with a nil object and explicit name" do
        template = rabl %q{
          object @user => :person
          attributes :name
        }
        scope = Object.new
        scope.instance_variable_set :@user, nil
        template.render(scope)
      end.equals "{}"
    end

    context "#collection" do
      asserts "that it sets object to be casted as a simple array" do
        template = rabl %{
          collection @users
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "[{},{}]"

      asserts "that it sets root node for objects using hash" do
        template = rabl %{
          collection @users => :people
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "{\"people\":[{},{}]}"

      asserts "that it sets root node for objects using root option" do
        template = rabl %{
          collection @users, :root => :people
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "{\"people\":[{},{}]}"

      asserts "that it sets root node for objects using object_root option" do
        template = rabl %{
          collection @users, :root => :humans, :object_root => :person
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals %Q^{"humans":[{"person":{}},{"person":{}}]}^
    end

    context "#attribute" do
      asserts "that it adds an attribute or method to be included in output" do
        template = rabl %{
          object @user
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope)
      end.equals "{\"name\":\"irvine\"}"

      asserts "that it can add attribute under a different key name through :as" do
        template = rabl %{
          object @user
          attribute :name, :as => 'city'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope)
      end.equals "{\"city\":\"irvine\"}"

      asserts "that it exposes root_object" do
        template = rabl %q{
          object @user

          attribute :name, :as => root_object.city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope)
      end.equals "{\"irvine\":\"irvine\"}"

      asserts "that it can add attribute under a different key name through hash" do
        template = rabl %{
          object @user
          attribute :name => :city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope)
      end.equals "{\"city\":\"irvine\"}"

      asserts "that it handle structs correctly as child elements" do
        template = rabl %{
          object @user
          child(:city) do
            attributes :name
          end
        }
        City = Struct.new(:name)
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:city => City.new('San Francisco'))
        template.render(scope)
      end.equals "{\"city\":{\"name\":\"San Francisco\"}}"

      asserts "that it can be passed an if cond for single real attr" do
        template = rabl %{
          object @user
          attribute :name
          attributes :age, :first, :if => lambda { |i| i.name != 'irvine' }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"name\":\"irvine\"}")

      asserts "that it can be passed an if cond for aliased attrs" do
        template = rabl %{
          object @user
          attributes :name => :title, :age => :year, :if => lambda { |i| i.name == 'irvine' }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"title\":\"irvine\",\"year\":24}")

      asserts "that it can be passed an unless cond to hide attrs" do
        template = rabl %{
          object @user
          attribute :name
          attributes :age, :unless => lambda { |i| i.name == 'irvine' }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"name\":\"irvine\"}")

      asserts "that it can be passed an unless cond for aliased attrs" do
        template = rabl %{
          object @user
          attributes :name => :title, :age => :year, :unless => lambda { |i| i.name == 'irvine' }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{}")
    end # attribute

    context "#code" do
      asserts "that it can create an arbitraty code node" do
        template = rabl %{
          code(:foo) { 'bar' }
        }
        template.render(Object.new)
      end.equals "{\"foo\":\"bar\"}"

      asserts "that it can be passed conditionals" do
        template = rabl %{
          code(:foo, :if => lambda { |i| false }) { 'bar' }
        }
        template.render(Object.new)
      end.equals "{}"
    end

    context "#child" do
      asserts "that it can create a singular child node" do
        template = rabl %{
          object @user
          attribute :name
          child(@user) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"name\":\"leo\",\"user\":{\"city\":\"LA\"}}")

      asserts "that it can create a singular child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(@user => :person) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"name\":\"leo\",\"person\":{\"city\":\"LA\"}}")

      asserts "that it can create a many child node" do
        template = rabl %{
          object @user
          attribute :name
          child(:hobbies) { attribute :name }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        JSON.parse(template.render(scope))
      end.equals JSON.parse(%q^{"name":"leo", "hobbies":[{"hobby":{"name":"Photography"}}]}^)

      asserts "that it can create a many child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(:hobbies => :interests) { attribute :name }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        JSON.parse(template.render(scope))
      end.equals JSON.parse(%q^{"name":"leo", "interests":[{"interest":{"name":"Photography"}}]}^)

      asserts "that it can create a many child node with no data" do
        template = rabl %{
          object @user
          attribute :name
          child(:hobbies) { attribute :name }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA', :hobbies => [])
        JSON.parse(template.render(scope))
      end.equals JSON.parse(%q^{"name":"leo", "hobbies":[]}^)

      asserts "that it can be passed conditionals" do
        template = rabl %{
          object @user
          attribute :name
          child({:children => :children}, {:if => lambda { |user| user.respond_to?('children') }}) { attribute :test }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope)
      end.equals "{\"name\":\"leo\"}"
    end

    context "#glue" do
      asserts "that it glues data from a child node" do
        template = rabl %{
          object @user
          attribute :name
          glue(@user) { attribute :city }
          glue(@user) { attribute :age  }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA', :age => 12)
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"name\":\"leo\",\"city\":\"LA\",\"age\":12}")

      asserts "that it can be passed conditionals" do
        template = rabl %{
          object @user
          attribute :name
          glue(@user, {:if => lambda { |i| false }}) { attribute :age  }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA', :age => 12)
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"name\":\"leo\"}")
    end

    context "#extends" do
      helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }
      setup do
        Rabl.configure do |config|
          config.view_paths = tmp_path
        end
        File.open(tmp_path + "test.json.rabl", "w") do |f|
          f.puts %q{
            attributes :age
          }
        end
      end

      asserts "that it extends the template with attributes from the file" do
        template = rabl %{
          object @user
          attribute :name
          extends 'test'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :age => 12)
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"name\":\"leo\",\"age\":12}")

      asserts "that it can be passed conditionals" do
        template = rabl %{
          object @user
          attribute :name
          extends('test', {:if => lambda { |i| false }})
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :age => 12)
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"name\":\"leo\"}")
    end

    teardown do
      Rabl.reset_configuration!
    end
  end # without json root

  context "without child root" do
    setup do
      Rabl.configure do |config|
        config.include_child_root    = false
        config.include_xml_root      = false
        config.enable_json_callbacks = false
      end
    end

    context "#child" do
      asserts "that it can create a child node without child root" do
        template = rabl %{
          child @users
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "{\"users\":[{},{}]}"
    end

    teardown do
      Rabl.reset_configuration!
    end
  end
end
