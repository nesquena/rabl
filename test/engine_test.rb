# frozen_string_literal: true

require 'erb'
require 'json'
require 'stringio'
require 'pathname'
require 'tmpdir'
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

  context "#apply" do
    denies("that it raises exception when given frozen locals").raises(RuntimeError) do
      Rabl::Engine.new("").apply(Object.new, {}.freeze)
    end

    asserts "that it can call method in block without arguments" do
      template = RablTemplate.new("code") { 'node(:foo) { func }' }
      obj = Object.new
      def obj.func
        "bar"
      end
      template.render(obj)
    end.equals "{\"foo\":\"bar\"}"

    asserts "that it can call method in block with positional arguments" do
      template = RablTemplate.new("code") { 'node(:foo) { func("bar") }' }
      obj = Object.new
      def obj.func(arg)
        "#{arg}"
      end
      template.render(obj)
    end.equals "{\"foo\":\"bar\"}"

    asserts "that it can call method in block with positional and keyword arguments" do
      template = RablTemplate.new("code") { 'node(:foo) { func("bar", kw: "baz") }' }
      obj = Object.new
      def obj.func(arg, kw:)
        "#{arg}-#{kw}"
      end
      template.render(obj)
    end.equals "{\"foo\":\"bar-baz\"}"
  end

  context "#request_format" do
    context "is json by default" do
      setup do
        template = RablTemplate.new("code") { 'node(:foo) { "bar" }' }
        template.render(Object.new)
      end

      asserts_topic.equivalent_to('{"foo":"bar"}')
    end

    context "with a specified format" do
      setup do
        template = RablTemplate.new("code", :format => 'xml') { 'node(:foo) { "bar" }' }
        template.render(Object.new)
      end

      asserts_topic.includes('<foo>bar</foo>')
    end

    context "don't allow calls to inherited methods; default to JSON" do
      code = 'node(:foo) { "bar" }'
      expected_json = '{"foo":"bar"}'
      setup do
        template = RablTemplate.new("code", :format => 's') { code }
        template.render(Object.new)
      end

      asserts_topic.equivalent_to(expected_json)

      setup do
        template = RablTemplate.new("code", :format => 'ruby') { code }
        template.render(Object.new)
      end

      asserts_topic.equivalent_to(expected_json)

      setup do
        template = RablTemplate.new("code", :format => 'enum') { code }
        template.render(Object.new)
      end

      asserts_topic.equivalent_to(expected_json)
    end
  end

  context "#cache" do
    context "with cache" do
      setup do
        template = Rabl::Engine.new(%q{
          cache 'foo'
        })
        template.render(Object.new)
        template
      end

      asserts_topic.assigns(:_cache_key) { 'foo' }
    end

    context "with cache and options" do
      setup do
        template = Rabl::Engine.new(%q{
          cache 'foo', :expires_in => 'bar'
        })
        template.render(Object.new)
        template
      end

      asserts_topic.assigns(:_cache_key) { 'foo' }
      asserts_topic.assigns(:_cache_options) { { :expires_in => 'bar' } }
    end

    context "without cache" do
      setup do
        template = Rabl::Engine.new("")
        template.render(Object.new)
        template
      end

      denies(:instance_variable_defined?, :@_cache_key)
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

      asserts "that it can set root node with a string" do
        template = rabl %q{
          object @user => 'person'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals "{\"person\":{}}"

      asserts "that it names collection elements after a string root node" do
        template = rabl %q{
          object @users => 'people'
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'a')]
        template.render(scope)
      end.equals "[{\"person\":{\"name\":\"a\"}}]"

      asserts "that it can set root node with a nil object and explicit name" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, nil
        template.render(scope)
      end.equals "{\"person\":{}}"

      asserts "that it can set false root node" do
        template = rabl %q{
          object @user => false
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals "{}"

      asserts "that it can set false root node and correctly render object without root node" do
        template = rabl %q{
          object @user => false
          attribute :name
        }
        user = User.new(:name => "John Doe")
        scope = Object.new
        scope.instance_variable_set :@user, user
        template.render(scope)
      end.equals "{\"name\":\"John Doe\"}"

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

      asserts "that it applies options given with a key alias" do
       template = rabl %{
         collection @users => :people, :object_root => false
       }
       scope = Object.new
       scope.instance_variable_set :@users, [User.new, User.new]
       template.render(scope)
      end.equals "{\"people\":[{},{}]}"

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

      asserts "that it reads a method_missing attribute named like a private Kernel method" do
        template = rabl %{
          object @doc => :doc
          attributes :id, :format
        }
        scope = Object.new
        scope.instance_variable_set :@doc, Hashie::Mash.new(:id => 1, :format => 'pdf')
        template.render(scope)
      end.equals "{\"doc\":{\"id\":1,\"format\":\"pdf\"}}"

      asserts "that it reads a method_missing child named like a private Kernel method" do
        template = rabl %{
          object @doc => :doc
          child(:format => :fmt) { attributes :name }
        }
        scope = Object.new
        scope.instance_variable_set :@doc, Hashie::Mash.new(:format => { :name => 'pdf' })
        template.render(scope)
      end.equals "{\"doc\":{\"fmt\":{\"name\":\"pdf\"}}}"

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
      asserts "that it can create an arbitrary code node" do
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

      asserts "that it can be passed conditionals given no name" do
        template = rabl %{
          collection @users
          code(:if => lambda { |u| u.name == 'a' }) do |user|
            {:city => user.city}
          end
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'a', :city => 'LA'), User.new(:name => 'b', :city => 'NY')]
        JSON.parse(template.render(scope))
      end.equals JSON.parse("[{\"user\":{\"city\":\"LA\"}},{\"user\":{}}]")
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

      asserts "that it chooses a name based on symbol if no elements" do
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

      asserts "that it chooses a name based on symbol if nil" do
        template = rabl %{
          object @bar => :bar
          child(:foos) { attribute :city }
        }
        scope = Object.new
        bar = Object.new
        stub(bar).foos { nil }
        scope.instance_variable_set :@bar, bar
        template.render(scope)
      end.equals "{\"bar\":{\"foos\":null}}"

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

      # #725: the :root form keeps its key like the hash form does
      asserts "it keeps a child named by :root when the collection is empty or nil" do
        [[], nil].map do |users|
          [%{child(@users, :root => "people", :object_root => false) { attribute :city }},
           %{child({ @users => :people }, :object_root => false) { attribute :city }}].map do |child_line|
            template = rabl "object @user\nattribute :name\n#{child_line}\n"
            scope = Object.new
            scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
            scope.instance_variable_set :@users, users
            template.render(scope)
          end
        end
      end.equals [["{\"user\":{\"name\":\"leo\",\"people\":[]}}"] * 2, ["{\"user\":{\"name\":\"leo\",\"people\":null}}"] * 2]

      asserts "it still skips a child named by :root when its data is false or an empty string" do
        [false, ''].map do |data|
          template = rabl %{
            object @user
            attribute :name
            child(@data, :root => "stats") { node(:total) { |s| s.total } }
          }
          scope = Object.new
          scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
          scope.instance_variable_set :@data, data
          template.render(scope)
        end
      end.equals ["{\"user\":{\"name\":\"leo\"}}"] * 2

      asserts "it still skips a child named by :root when its condition is false" do
        template = rabl %{
          object @user
          attribute :name
          child(@users, :root => "people", :if => lambda { |u| false }) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        scope.instance_variable_set :@users, []
        template.render(scope)
      end.equals "{\"user\":{\"name\":\"leo\"}}"

      asserts "that it applies a false condition given with a key alias" do
        template = rabl %{
          object @user
          attribute :name
          child :hobbies => :interests, :if => lambda { |u| false } do
            attribute :name
          end
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo')
        template.render(scope)
      end.equals "{\"user\":{\"name\":\"leo\"}}"

      asserts "that it renders a child given a key alias and a true condition" do
        template = rabl %{
          object @user
          child :hobbies => :interests, :unless => lambda { |u| false } do
            attribute :name
          end
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :hobbies => ['Photography'])
        template.render(scope)
      end.equals "{\"user\":{\"interests\":[{\"interest\":{\"name\":\"Photography\"}}]}}"

      asserts "that it applies root options given with a key alias" do
        template = rabl %{
          object @user
          child :hobbies => :interests, :object_root => false do
            attribute :name
          end
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :hobbies => ['Photography'])
        template.render(scope)
      end.equals "{\"user\":{\"interests\":[{\"name\":\"Photography\"}]}}"

      asserts "that it keeps a hash that is not a single key alias as the data" do
        template = rabl %{
          object @user
          child(@pairs) { node(:key) { |pair| pair.first } }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        scope.instance_variable_set :@pairs, { :name => :pairs, :if => false, :age => 'x' }
        template.render(scope)
      end.equals "{\"user\":{\"pairs\":[{\"pair\":{\"key\":\"name\"}},{\"pair\":{\"key\":\"if\"}},{\"pair\":{\"key\":\"age\"}}]}}"
    end

    context "#glue" do
      asserts "that it applies a condition given with a key alias" do
        template = rabl %{
          collection @users
          attribute :name
          glue @home => :home, :if => lambda { |u| u.name == 'leo' } do
            attribute :city
          end
        }
        scope = Object.new
        scope.instance_variable_set :@home, User.new(:city => 'LA')
        scope.instance_variable_set :@users, [User.new(:name => 'leo'), User.new(:name => 'max')]
        template.render(scope)
      end.equals "[{\"user\":{\"name\":\"leo\",\"city\":\"LA\"}},{\"user\":{\"name\":\"max\"}}]"

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
        e = Rabl::Engine.new(nil)
        mock(e).render.returns({ :name => 'leo', :city => 'LA', :age => 12 })

        any_instance_of(Rabl::Engine) do |b|
          mock(b).fetch_source("foo/bar", :view_path => nil).once
          mock(b).object_to_engine(@user, { :locals => { :foo => "bar" }, :source => nil, :source_location => nil, :template => 'foo/bar' }).returns(e)
        end
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{ \"foo\" : {\"name\":\"leo\",\"city\":\"LA\",\"age\":12} }")

      # Templates that call attribute, node, child, glue or extends inside a node block (#477)
      helper(:node_scope) do
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo')
        scope.instance_variable_set :@users, [User.new(:name => 'a'), User.new(:name => 'b')]
        scope
      end

      # [output, number of warnings about method_name] of rendering source
      helper(:render_capturing_warnings) do |source, method_name|
        stderr, verbose = $stderr, $VERBOSE
        $stderr, $VERBOSE = StringIO.new, false
        begin
          output = rabl(source).render(node_scope)
          [output, $stderr.string.scan(/^rabl: #{method_name} called while the template renders .*use partial/).size]
        ensure
          $stderr, $VERBOSE = stderr, verbose
        end
      end

      asserts "that extends inside a node warns and leaves out the template settings" do
        render_capturing_warnings(%{
          object false
          node(:foo) { extends("foo/bar", :object => @user) }
        }, :extends)
      end.equals { [rabl("object false\nnode(:foo) { nil }").render(node_scope), 1] }

      asserts "that extends inside a nameless node warns and renders as without it" do
        render_capturing_warnings(%{
          object @user
          attribute :name
          node { |u| extends 'foo/bar'; { :x => 1 } }
        }, :extends)
      end.equals { [rabl("object @user\nattribute :name\nnode { |u| { :x => 1 } }").render(node_scope), 1] }

      asserts "that extends inside a node of a collection doesn't change the template" do
        render_capturing_warnings(%{
          collection @users
          attribute :name
          node(false) { |u| extends 'foo/bar' }
        }, :extends)
      end.equals { [rabl("collection @users\nattribute :name").render(node_scope), 2] }

      asserts "that attribute inside a node warns and renders as before" do
        render_capturing_warnings(%{
          object @user
          node(:foo) { attribute :name }
        }, :attribute)
      end.equals { [rabl("object @user\nnode(:foo) { [:name] }").render(node_scope), 1] }

      asserts "that child inside a node warns and renders as before" do
        render_capturing_warnings(%{
          object @user
          node(:foo) { child(:city); 1 }
        }, :child)
      end.equals { [rabl("object @user\nnode(:foo) { 1 }").render(node_scope), 1] }

      asserts "that glue inside a node warns and renders as before" do
        render_capturing_warnings(%{
          object @user
          node(:foo) { glue(:city); 1 }
        }, :glue)
      end.equals { [rabl("object @user\nnode(:foo) { 1 }").render(node_scope), 1] }

      asserts "that node inside a node warns and renders as before" do
        render_capturing_warnings(%{
          object @user
          node(:foo) { node(:bar) { 1 }; 2 }
        }, :node)
      end.equals { [rabl("object @user\nnode(:foo) { 2 }\nnode(:bar) { 1 }").render(node_scope), 1] }
    end

    teardown do
      Rabl.reset_configuration!
    end
  end # with json root

  context "with escape_all_output" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }
    setup do
      Rabl.configure do |config|
        config.include_json_root = false
        config.escape_all_output = true
        config.view_paths        = tmp_path
      end
      File.open(tmp_path + "city.rabl", "w") { |f| f.puts "attributes :city" }
    end

    asserts "that it escapes values rendered by child, glue, extends and partial once" do
      template = rabl %{
        object @user
        attribute :name
        child(@user => :person) { attribute :city }
        glue(@user) { attribute :twitter }
        extends 'city'
        node(:partial) { |user| partial('city', :object => user) }
      }
      scope = Object.new
      scope.instance_variable_set :@user, User.new(:name => 'a&b', :city => 'c<d', :twitter => '"e"')
      JSON.parse(template.render(scope))
    end.equals JSON.parse(%q{{"name":"a&amp;b","person":{"city":"c&lt;d"},"twitter":"&quot;e&quot;","city":"c&lt;d","partial":{"city":"c&lt;d"}}})

    asserts "that it escapes values rendered by a child in a collection once" do
      template = rabl %{
        collection @users
        child(:hobbies) { attribute :name }
      }
      scope = Object.new
      scope.instance_variable_set :@users, [User.new(:hobbies => ['a&b'])]
      template.render(scope)
    end.equals %q{[{"hobbies":[{"hobby":{"name":"a&amp;b"}}]}]}

    teardown do
      Rabl.reset_configuration!
    end
  end

  context "with escape_all_output and caching" do
    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }
    helper(:cached_post) do |id|
      post = User.new(:name => '<b>')
      post.define_singleton_method(:cache_key) { "cached_post/#{id}" }
      post
    end
    # the post as a nested template (child + extends), and as a top level :format => 'hash' render
    helper(:render_post) do |kind, post|
      if kind == :nested
        holder = User.new(:first => post)
        Rabl::Renderer.new("object @holder\nchild(:first => :post) { extends 'cached_post' }\n", holder, :format => 'json', :view_path => tmp_path, :scope => Object.new).render
      else
        Rabl::Renderer.new('cached_post', post, :format => 'hash', :view_path => tmp_path).render
      end
    end
    setup do
      Rabl.configure do |config|
        config.perform_caching   = true
        config.escape_all_output = true
        config.include_json_root = false
        config.cache_engine      = Rabl::CacheEngine.new
      end
      File.open(tmp_path + "cached_post.rabl", "w") { |f| f.puts "object @user\ncache root_object\nattributes :name" }
    end

    asserts "that a top level hash render after a nested one is escaped" do
      post = cached_post(1)
      [render_post(:nested, post), render_post(:hash, post)]
    end.equals ["{\"post\":{\"name\":\"&lt;b&gt;\"}}", { :name => "&lt;b&gt;" }]

    asserts "that a nested render after a top level hash one is escaped once" do
      post = cached_post(2)
      [render_post(:hash, post), render_post(:nested, post)]
    end.equals [{ :name => "&lt;b&gt;" }, "{\"post\":{\"name\":\"&lt;b&gt;\"}}"]

    teardown do
      Rabl.reset_configuration!
    end
  end

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
      asserts "that it can create an arbitrary code node" do
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
            node(:city) { "Gotham" } if locals[:show_city]
          }
        end
        File.open(tmp_path + "friend.json.rabl", "w") do |f|
          f.puts %q{
            node(:uid) { |friend| friend['uid'] }
            node(:keys) { |friend| friend.is_a?(Hash) ? friend.keys.size : friend.class.name }
          }
        end
        File.open(tmp_path + "friend_object.json.rabl", "w") do |f|
          f.puts %q{
            object @friend
            extends 'friend'
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

      asserts "that it can be passed locals" do
        template = rabl %{
          object @user
          attribute :name
          extends 'test', :locals => { :show_city => true }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :age => 12)
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"name\":\"leo\",\"age\":12,\"city\":\"Gotham\"}")

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

      # #396: a Hash item handed down by extends is data, not `@object => :name` syntax
      asserts "that it extends each Hash item of a collection with its own values" do
        [%{collection @friends\nextends 'friend'\n},
         %{extends 'friend'\ncollection @friends\n},
         %{collection @friends\nextends 'friend_object'\n}].map do |source|
          scope = Object.new
          scope.instance_variable_set :@friends, [{ 'uid' => 'a' }, { 'uid' => 'b', 'n' => 2 }]
          JSON.parse(rabl(source).render(scope))
        end
      end.equals [[{ "uid" => "a", "keys" => 1 }, { "uid" => "b", "keys" => 2 }]] * 3

      asserts "that an explicit :object keeps the alias syntax" do
        template = rabl %{
          object @user
          attribute :name
          extends 'test', :object => { @other => :person }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :age => 12)
        scope.instance_variable_set :@other, User.new(:name => 'max', :age => 40)
        JSON.parse(template.render(scope))
      end.equals JSON.parse("{\"name\":\"leo\",\"age\":40}")
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
