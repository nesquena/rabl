require File.expand_path('../teststrap', __FILE__)
require File.expand_path('../../lib/rabl', __FILE__)
require File.expand_path('../../lib/rabl/template', __FILE__)
require File.expand_path('../models/user', __FILE__)
require File.expand_path('../models/ormless', __FILE__)

context "Rabl::Engine" do

  helper(:rabl) { |t| RablTemplate.new { t } }

  context "#initialize" do
    setup do
      Rabl::Engine.new("...source...", { :format => 'xml', :root => true, :view_path => '/path/to/views' })
    end

    asserts_topic.assigns :_source
    asserts_topic.assigns :_options
  end


  context "with defaults" do
    setup do
      Rabl.configure do |config|
        config.include_json_root     = true
        config.include_xml_root      = false
        config.enable_json_callbacks = false
      end
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
         collection @users => :users
       }
       scope = Object.new
       scope.instance_variable_set :@users, [User.new, User.new]
       template.render(scope)
      end.equals "{\"users\":[{\"user\":{}},{\"user\":{}}]}"

      asserts "that it doesn't set root node for objects when specified" do
       template = rabl %{
         collection @users, :root => :users, :object_root => false
       }
       scope = Object.new
       scope.instance_variable_set :@users, [User.new, User.new]
       template.render(scope)
      end.equals "{\"users\":[{},{}]}"

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
        template.render(scope).split('').sort
      end.equals "{\"user\":{\"name\":\"irvine\"}}".split('').sort

      asserts "that it can add attribute under a different key name through :as" do
        template = rabl %{
          object @user
          attribute :name, :as => 'city'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split('').sort
      end.equals "{\"user\":{\"city\":\"irvine\"}}".split('').sort

      asserts "that it can add attribute under a different key name through hash" do
        template = rabl %{
          object @user
          attribute :name => :city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split('').sort
      end.equals "{\"user\":{\"city\":\"irvine\"}}".split('').sort

    end

    context "#code" do

      asserts "that it can create an arbitraty code node" do
        template = rabl %{
          code(:foo) { 'bar' }
        }
        template.render(Object.new).split('').sort
      end.equals "{\"foo\":\"bar\"}".split('').sort

      asserts "that it can be passed conditionals" do
        template = rabl %{
          code(:foo, :if => lambda { |i| false }) { 'bar' }
        }
        template.render(Object.new).split('').sort
      end.equals "{}".split('').sort

      asserts "that it can merge the result with a collection element given no name" do
        template = rabl %{
          collection @users
          code do |user|
            {:name => user.name}
          end
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'a'), User.new(:name => 'b')]
        template.render(scope).split('').sort
      end.equals "[{\"user\":{\"name\":\"a\"}},{\"user\":{\"name\":\"b\"}}]".split('').sort

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
        template.render(scope).split('').sort
      end.equals "{\"user\":{\"name\":\"leo\",\"user\":{\"city\":\"LA\"}}}".split('').sort

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
        template.render(scope).split('').sort
      end.equals "{\"user\":{\"name\":\"leo\",\"user\":{\"city\":\"LA\"}}}".split('').sort

      asserts "that it can create a child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(@user => :person) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope).split('').sort

      end.equals "{\"user\":{\"name\":\"leo\",\"person\":{\"city\":\"LA\"}}}".split('').sort
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
        template.render(scope).split('').sort
      end.equals "{\"user\":{\"name\":\"leo\",\"city\":\"LA\",\"age\":12}}".split('').sort
    end

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

      asserts "that it can add attribute under a different key name through hash" do
        template = rabl %{
          object @user
          attribute :name => :city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope)
      end.equals "{\"city\":\"irvine\"}"

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
        template.render(scope).split('').sort
      end.equals "{\"name\":\"leo\",\"user\":{\"city\":\"LA\"}}".split('').sort

      asserts "that it can create a child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(@user => :person) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope).split('').sort

      end.equals "{\"name\":\"leo\",\"person\":{\"city\":\"LA\"}}".split('').sort


      asserts "that it can be passed conditionals" do
        template = rabl %{
          object @user
          attribute :name
          child({:children => :children}, {:if => lambda { |user| user.respond_to?('children') }}) { attribute :test }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope).split('').sort

      end.equals "{\"name\":\"leo\"}".split('').sort

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
        template.render(scope).split('').sort
      end.equals "{\"name\":\"leo\",\"city\":\"LA\",\"age\":12}".split('').sort
    end

    teardown do
      Rabl.reset_configuration!
    end
  end
end
