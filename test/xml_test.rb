require 'active_support/core_ext/hash/conversions'
require File.expand_path('../teststrap', __FILE__)
require 'rabl/template'

context "Rabl::Engine" do
  helper(:rabl) { |t| RablTemplate.new("code", :format => 'xml') { t } }

  # TODO fix annoying warnings in this file:
  # gems/builder-3.0.3/lib/builder/xmlbase.rb:181: warning: method redefined; discarding old user
  setup { @old_verbose, $VERBOSE = $VERBOSE, nil }
  teardown { $VERBOSE = @old_verbose }

  context "with xml defaults" do
    setup do
      Rabl.configure do |config|
        # Comment this line out because include_xml_root to false is default.
        #config.include_xml_root = false
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
      end.matches ""

      asserts "that it can set root node" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<person>\n</person>\n"
    end

    context "#collection" do
      asserts "that it sets object to be casted as a simple array" do
        template = rabl %{
          collection @users
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<users type=\"array\">\n  <user>\n  </user>\n  <user>\n  </user>\n</users>\n"

      asserts "that it sets root node for objects" do
        template = rabl %{
          collection @users => :smors
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<smors type=\"array\">\n  <smor>\n  </smor>\n  <smor>\n  </smor>\n</smors>\n"
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
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <name>irvine</name>\n</user>\n"

      asserts "that it can add attribute under a different key name through :as" do
        template = rabl %{
          object @user
          attribute :name, :as => 'city'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <city>irvine</city>\n</user>\n"

      asserts "that it can add attribute under a different key name through hash" do
        template = rabl %{
          object @user
          attribute :name => :city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <city>irvine</city>\n</user>\n"
    end

    context "#code" do
      asserts "that it can create an arbitraty code node" do
        template = rabl %{
          code(:foo) { 'bar' }
        }
        template.render(Object.new)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<hash>\n  <foo>bar</foo>\n</hash>\n"

      asserts "that it can be passed conditionals" do
        template = rabl %{
          code(:foo, :if => lambda { |i| false }) { 'bar' }
        }
        template.render(Object.new)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<hash>\n</hash>\n"
    end

    context "#child" do
      asserts "that it can create a child node" do
        template = rabl %{
          object @user
          child(@user) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <user>\n    <city>LA</city>\n  </user>\n</user>\n"

      asserts "that it can create a child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(@user => :person) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <name>leo</name>\n  <person>\n    <city>LA</city>\n  </person>\n</user>\n"
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
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <name>leo</name>\n  <city>LA</city>\n  <age type=\"integer\">12</age>\n</user>\n"
    end

    teardown do
      Rabl.reset_configuration!
    end
  end

  context "with xml root" do
    setup do
      Rabl.configure do |config|
        config.include_xml_root = true
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
      end.matches "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <user>\n  </user>\n</user>\n"

      asserts "that it can set root node" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<person>\n  <person>\n  </person>\n</person>\n"
    end

    context "#collection" do
      asserts "that it sets object to be casted as a simple array" do
        template = rabl %{
          collection @users
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<users type=\"array\">\n  <user>\n    <user>\n    </user>\n  </user>\n  <user>\n    <user>\n    </user>\n  </user>\n</users>\n"

      asserts "that it sets root node for objects" do
        template = rabl %{
          collection @users => :people
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<people type=\"array\">\n  <person>\n    <person>\n    </person>\n  </person>\n  <person>\n    <person>\n    </person>\n  </person>\n</people>\n"

      asserts "that it sets root node for objects with :root parameter" do
        template = rabl %{
          collection @users, :root => :people, :object_root => :person
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<people type=\"array\">\n  <person>\n    <person>\n    </person>\n  </person>\n  <person>\n    <person>\n    </person>\n  </person>\n</people>\n"

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
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <user>\n    <name>irvine</name>\n  </user>\n</user>\n"

      asserts "that it can add attribute under a different key name through :as" do
        template = rabl %{
          object @user
          attribute :name, :as => 'city'
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <user>\n    <city>irvine</city>\n  </user>\n</user>\n"

      asserts "that it can add attribute under a different key name through hash" do
        template = rabl %{
          object @user
          attribute :name => :city
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'irvine')
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <user>\n    <city>irvine</city>\n  </user>\n</user>\n"
    end

    context "#code" do
      asserts "that it can create an arbitrary code node" do
        template = rabl %{
          code(:foo) { 'bar' }
        }
        template.render(Object.new)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<hash>\n  <foo>bar</foo>\n</hash>\n"

      asserts "that it can be passed conditionals" do
        template = rabl %{
          code(:foo, :if => lambda { |i| false }) { 'bar' }
        }
        template.render(Object.new)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<hash>\n</hash>\n"
    end

    context "#child" do
      asserts "that it can create a child node" do
        template = rabl %{
          object @user
          child(@user) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <user>\n    <user>\n      <city>LA</city>\n    </user>\n  </user>\n</user>\n"

      asserts "that it can create a child node with different key" do
        template = rabl %{
          object @user
          attribute :name
          child(@user => :person) { attribute :city }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <user>\n    <name>leo</name>\n    <person>\n      <city>LA</city>\n    </person>\n  </user>\n</user>\n"
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
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <user>\n    <name>leo</name>\n    <city>LA</city>\n    <age type=\"integer\">12</age>\n  </user>\n</user>\n"
    end

    teardown do
      Rabl.reset_configuration!
    end
  end
end
