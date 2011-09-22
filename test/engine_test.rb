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

      # TODO fix this test
      # asserts "that it sets root node for objects" do
      #   template = rabl %{
      #     collection @users => :people
      #   }
      #   scope = Object.new
      #   scope.instance_variable_set :@users, [User.new, User.new]
      #   template.render(scope)
      # end.equals "{\"people\":[{\"person\":{}},{\"person\":{}}]}"

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
      
      asserts "that it can create a child node with a single argument" do
        template = rabl %{
          object @user
          attribute :name
          child(:set_age, :args => 27) { attribute :age }
        }
        scope = Object.new
        @user = User.new(:name => 'leo', :city => 'LA')
        @user.define_singleton_method(:set_age) do |age|
          self.age = age
          self
        end
        scope.instance_variable_set :@user, @user
        template.render(scope).split('').sort
        
      end.equals "{\"user\":{\"name\":\"leo\",\"user\":{\"age\":27}}}".split('').sort
      
      asserts "that it can create a child node with an argument that is an array" do
        template = rabl %{
          object @user
          attribute :name
          child(:set_random_age, :args => [[18,27]]) { attribute :age }
        }
        scope = Object.new
        @user = User.new(:name => 'leo', :city => 'LA')
        @user.define_singleton_method(:set_random_age) do |ages|
          self.age = ages[rand(ages.size)]
          self
        end
        scope.instance_variable_set :@user, @user
        result = template.render(scope).split('').sort
        result == "{\"user\":{\"name\":\"leo\",\"user\":{\"age\":18}}}".split('').sort || 
                  "{\"user\":{\"name\":\"leo\",\"user\":{\"age\":27}}}".split('').sort
      end
      
      asserts "that it can create a child node with multiple arguments" do
        template = rabl %{
          object @user
          attribute :name
          child(:set_age_and_city, :args => [27, "Shreveport"]) { attributes :age, :city }
        }
        scope = Object.new
        @user = User.new(:name => 'leo', :city => 'LA')
        @user.define_singleton_method(:set_age_and_city) do |age, city|
          self.age = age
          self.city = city
          self
        end
        scope.instance_variable_set :@user, @user
        template.render(scope).split('').sort
        
      end.equals "{\"user\":{\"name\":\"leo\",\"user\":{\"age\":27,\"city\":\"Shreveport\"}}}".split('').sort
      
      asserts "that it can create a child node with an argument with a different key" do
        template = rabl %{
          object @user
          attribute :name
          child({ :set_age => :person }, { :args => 27 }) { attribute :age }
        }
        scope = Object.new
        @user = User.new(:name => 'leo', :city => 'LA')
        @user.define_singleton_method(:set_age) do |age|
          self.age = age
          self
        end
        scope.instance_variable_set :@user, @user
        template.render(scope).split('').sort
        
      end.equals "{\"user\":{\"name\":\"leo\",\"person\":{\"age\":27}}}".split('').sort
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

      asserts "that it sets root node for objects" do
        template = rabl %{
          collection @users => :person
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "{\"person\":[{},{}]}"

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
