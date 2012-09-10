require File.expand_path('../teststrap', __FILE__)
require 'rabl/template'

context "Rabl::Engine" do
  helper(:rabl) { |t| RablTemplate.new("code", :format => 'bson') { t } }

  context "with bson defaults" do
    setup do
      Rabl.configure do |config|
        # Comment this line out because include_bson_root is default.
        #config.include_bson_root = true
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
      end.matches "\x10\x00\x00\x00\x03user\x00\x05\x00\x00\x00\x00\x00"

      asserts "that it can set root node" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope).split("").sort
      end.equals "\x12\x00\x00\x00\x03person\x00\x05\x00\x00\x00\x00\x00".split("").sort
    end

    context "#collection" do
      asserts "that it sets object to be casted as a simple array" do
        template = rabl %{
          collection @users
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope).split("").sort
      end.equals "7\x00\x00\x00\x04users\x00+\x00\x00\x00\x030\x00\x10\x00\x00\x00\x03user\x00\x05\x00\x00\x00\x00\x00\x031\x00\x10\x00\x00\x00\x03user\x00\x05\x00\x00\x00\x00\x00\x00\x00".split("").sort

      asserts "that it sets root node for objects" do
        template = rabl %{
          collection @users => :people
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope).split("").sort
      end.equals "<\x00\x00\x00\x04people\x00/\x00\x00\x00\x030\x00\x12\x00\x00\x00\x03person\x00\x05\x00\x00\x00\x00\x00\x031\x00\x12\x00\x00\x00\x03person\x00\x05\x00\x00\x00\x00\x00\x00\x00".split("").sort
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
      end.equals "!\x00\x00\x00\x03user\x00\x16\x00\x00\x00\x02name\x00\a\x00\x00\x00irvine\x00\x00\x00".split("").sort

      asserts "that it can add attribute under a different key name through :as" do
        template = rabl %{
          object @user
          attribute :name, :as => 'city'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split("").sort
      end.equals "!\x00\x00\x00\x03user\x00\x16\x00\x00\x00\x02city\x00\a\x00\x00\x00irvine\x00\x00\x00".split("").sort

      asserts "that it can add attribute under a different key name through hash" do
        template = rabl %{
          object @user
          attribute :name => :city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split("").sort
      end.equals "!\x00\x00\x00\x03user\x00\x16\x00\x00\x00\x02city\x00\a\x00\x00\x00irvine\x00\x00\x00".split("").sort
    end

    context "#code" do
      asserts "that it can create an arbitraty code node" do
        template = rabl %{
          code(:foo) { 'bar' }
        }
        template.render(Object.new).split("").sort
      end.equals "\x12\x00\x00\x00\x02foo\x00\x04\x00\x00\x00bar\x00\x00".split("").sort

      asserts "that it can be passed conditionals" do
        template = rabl %{
          code(:foo, :if => lambda { |i| false }) { 'bar' }
        }
        template.render(Object.new).split("").sort
      end.equals "\x05\x00\x00\x00\x00".split("").sort
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
      end.equals "6\x00\x00\x00\x03user\x00+\x00\x00\x00\x02name\x00\x04\x00\x00\x00leo\x00\x03user\x00\x12\x00\x00\x00\x02city\x00\x03\x00\x00\x00LA\x00\x00\x00\x00".split("").sort

      asserts "that it can create a child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(@user => :person) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope).split("").sort
      end.equals "8\x00\x00\x00\x03user\x00-\x00\x00\x00\x02name\x00\x04\x00\x00\x00leo\x00\x03person\x00\x12\x00\x00\x00\x02city\x00\x03\x00\x00\x00LA\x00\x00\x00\x00".split("").sort
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
      end.equals "4\x00\x00\x00\x03user\x00)\x00\x00\x00\x02name\x00\x04\x00\x00\x00leo\x00\x02city\x00\x03\x00\x00\x00LA\x00\x10age\x00\f\x00\x00\x00\x00\x00".split("").sort
    end

    teardown do
      Rabl.reset_configuration!
    end
  end

  context "with bson_engine" do
    setup do
      class CustomEncodeEngine
        def self.serialize string
          42
        end
      end

      Rabl.configure do |config|
        config.bson_engine = CustomEncodeEngine
      end
    end

    asserts 'that it returns process by custom to_json' do
      template = rabl %q{
        object @user
      }
      scope = Object.new
      scope.instance_variable_set :@user, User.new
      template.render(scope)
    end.equals "42"

    teardown do
      Rabl.reset_configuration!
    end
  end

  context "without bson root" do
    setup do
      Rabl.configure do |config|
        config.include_bson_root = false
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
      end.matches "\x05\x00\x00\x00\x00"

      asserts "that it can set root node" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals "\x05\x00\x00\x00\x00"
    end

    context "#collection" do
      asserts "that it sets object to be casted as a simple array" do
        template = rabl %{
          collection @users
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope).split("").sort
      end.equals "!\x00\x00\x00\x04users\x00\x15\x00\x00\x00\x030\x00\x05\x00\x00\x00\x00\x031\x00\x05\x00\x00\x00\x00\x00\x00".split("").sort

      asserts "that it sets root node for objects" do
        template = rabl %{
          collection @users => :person
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope).split("").sort
      end.equals "\"\x00\x00\x00\x04person\x00\x15\x00\x00\x00\x030\x00\x05\x00\x00\x00\x00\x031\x00\x05\x00\x00\x00\x00\x00\x00".split("").sort
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
      end.equals "\x16\x00\x00\x00\x02name\x00\a\x00\x00\x00irvine\x00\x00".split("").sort

      asserts "that it can add attribute under a different key name through :as" do
        template = rabl %{
          object @user
          attribute :name, :as => 'city'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split("").sort
      end.equals "\x16\x00\x00\x00\x02city\x00\a\x00\x00\x00irvine\x00\x00".split("").sort

      asserts "that it can add attribute under a different key name through hash" do
        template = rabl %{
          object @user
          attribute :name => :city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope).split("").sort
      end.equals "\x16\x00\x00\x00\x02city\x00\a\x00\x00\x00irvine\x00\x00".split("").sort
    end

    context "#code" do
      asserts "that it can create an arbitraty code node" do
        template = rabl %{
          code(:foo) { 'bar' }
        }
        template.render(Object.new).split("").sort
      end.equals "\x12\x00\x00\x00\x02foo\x00\x04\x00\x00\x00bar\x00\x00".split("").sort

      asserts "that it can be passed conditionals" do
        template = rabl %{
          code(:foo, :if => lambda { |i| false }) { 'bar' }
        }
        template.render(Object.new).split("").sort
      end.equals "\x05\x00\x00\x00\x00".split("").sort
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
      end.equals "+\x00\x00\x00\x02name\x00\x04\x00\x00\x00leo\x00\x03user\x00\x12\x00\x00\x00\x02city\x00\x03\x00\x00\x00LA\x00\x00\x00".split("").sort

      asserts "that it can create a child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(@user => :person) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope).split("").sort
      end.equals "-\x00\x00\x00\x02name\x00\x04\x00\x00\x00leo\x00\x03person\x00\x12\x00\x00\x00\x02city\x00\x03\x00\x00\x00LA\x00\x00\x00".split("").sort
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
      end.equals ")\x00\x00\x00\x02name\x00\x04\x00\x00\x00leo\x00\x02city\x00\x03\x00\x00\x00LA\x00\x10age\x00\f\x00\x00\x00\x00".split("").sort
    end

    teardown do
      Rabl.reset_configuration!
    end
  end
end
