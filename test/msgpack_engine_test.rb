require File.expand_path('../teststrap', __FILE__)
require 'rabl/template'

context "Rabl::Engine" do
  helper(:rabl) { |t| RablTemplate.new("code", :format => 'msgpack') { t } }

  context "with msgpack defaults" do
    setup do
      Rabl.configure do |config|
        # Comment this line out because include_msgpack_root is default.
        #config.include_msgpack_root = true
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
      end.matches "\x81\xA4user\x80"

      asserts "that it can set root node" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope).split("").sort
      end.equals "\x81\xA6person\x80".split("").sort
    end

    context "#collection" do
      asserts "that it sets object to be casted as a simple array" do
        template = rabl %{
          collection @users
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope).split("").sort
      end.equals "\x92\x81\xA4user\x80\x81\xA4user\x80".split("").sort

      asserts "that it sets root node for objects" do
        template = rabl %{
          collection @users => :person
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope).split("").sort
      end.equals "\x81\xA6person\x92\x81\xA6person\x80\x81\xA6person\x80".split("").sort
    end

    context "#attribute" do
      asserts "that it adds an attribute or method to be included in output" do
        template = rabl %{
          object @user
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split("").sort
      end.equals "\x81\xA4user\x81\xA4name\xA6irvine".split("").sort

      asserts "that it can add attribute under a different key name through :as" do
        template = rabl %{
          object @user
          attribute :name, :as => 'city'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split("").sort
      end.equals "\x81\xA4user\x81\xA4city\xA6irvine".split("").sort

      asserts "that it can add attribute under a different key name through hash" do
        template = rabl %{
          object @user
          attribute :name => :city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split("").sort
      end.equals "\x81\xA4user\x81\xA4city\xA6irvine".split("").sort
    end

    context "#code" do
      asserts "that it can create an arbitraty code node" do
        template = rabl %{
          code(:foo) { 'bar' }
        }
        template.render(Object.new).split("").sort
      end.equals "\x81\xA3foo\xA3bar".split("").sort

      asserts "that it can be passed conditionals" do
        template = rabl %{
          code(:foo, :if => lambda { |i| false }) { 'bar' }
        }
        template.render(Object.new).split("").sort
      end.equals "\x80".split("").sort
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
        template.render(scope).split("").sort
      end.equals "\x81\xA4user\x82\xA4name\xA3leo\xA4user\x81\xA4city\xA2LA".split("").sort

      asserts "that it can create a child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(@user => :person) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope).split("").sort

      end.equals "\x81\xA4user\x82\xA4name\xA3leo\xA6person\x81\xA4city\xA2LA".split("").sort
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
        template.render(scope).split("").sort
      end.equals "\x81\xA4user\x83\xA4name\xA3leo\xA4city\xA2LA\xA3age\f".split("").sort
    end

    teardown do
      Rabl.reset_configuration!
    end
  end

  context "with msgpack_engine" do
    setup do
      class CustomEncodeEngine
        def self.pack string
          42
        end
      end

      Rabl.configure do |config|
        config.msgpack_engine = CustomEncodeEngine
      end
    end

    asserts 'that it returns process by custom to_json' do
      template = rabl %q{
        object @user
      }
      scope = Object.new
      scope.instance_variable_set :@user, User.new
      template.render(scope)
    end.equals 42

    teardown do
      Rabl.reset_configuration!
    end
  end

  context "without msgpack root" do
    setup do
      Rabl.configure do |config|
        config.include_msgpack_root = false
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
      end.matches "\x80"

      asserts "that it can set root node" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals "\x80"
    end

    context "#collection" do
      asserts "that it sets object to be casted as a simple array" do
        template = rabl %{
          collection @users
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope).split("").sort
      end.equals "\x92\x80\x80".split("").sort

      asserts "that it sets root node for objects" do
        template = rabl %{
          collection @users => :person
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope).split("").sort
      end.equals "\x81\xA6person\x92\x80\x80".split("").sort
    end

    context "#attribute" do
      asserts "that it adds an attribute or method to be included in output" do
        template = rabl %{
          object @user
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split("").sort
      end.equals "\x81\xA4name\xA6irvine".split("").sort

      asserts "that it can add attribute under a different key name through :as" do
        template = rabl %{
          object @user
          attribute :name, :as => 'city'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split("").sort
      end.equals "\x81\xA4city\xA6irvine".split("").sort

      asserts "that it can add attribute under a different key name through hash" do
        template = rabl %{
          object @user
          attribute :name => :city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split("").sort
      end.equals "\x81\xA4city\xA6irvine".split("").sort
    end

    context "#code" do
      asserts "that it can create an arbitraty code node" do
        template = rabl %{
          code(:foo) { 'bar' }
        }
        template.render(Object.new).split("").sort
      end.equals "\x81\xA3foo\xA3bar".split("").sort

      asserts "that it can be passed conditionals" do
        template = rabl %{
          code(:foo, :if => lambda { |i| false }) { 'bar' }
        }
        template.render(Object.new).split("").sort
      end.equals "\x80".split("").sort
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
        template.render(scope).split("").sort
      end.equals "\x82\xA4name\xA3leo\xA4user\x81\xA4city\xA2LA".split("").sort

      asserts "that it can create a child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(@user => :person) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope).split("").sort
      end.equals "\x82\xA4name\xA3leo\xA6person\x81\xA4city\xA2LA".split("").sort
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
        template.render(scope).split("").sort
      end.equals "\x83\xA4name\xA3leo\xA4city\xA2LA\xA3age\f".split("").sort
    end

    teardown do
      Rabl.reset_configuration!
    end
  end
end
