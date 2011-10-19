require File.expand_path('../teststrap', __FILE__)
require File.expand_path('../../lib/rabl', __FILE__)
require File.expand_path('../../lib/rabl/template', __FILE__)
require File.expand_path('../models/user', __FILE__)
require 'active_support/core_ext/hash'

context "Rabl::Engine" do

  XML_INSTRUCT = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"

  helper(:rabl) { |t| RablTemplate.new("code", :format => 'xml') { t } }

  context "with xml defaults" do

    setup do
      Rabl.configure do |config|
        # Comment this line out because include_xml_root is default.
        #config.include_xml_root = false
      end
    end

    asserts "that it add xml instruct" do
      template = rabl %q{
        object false
      }
      scope = Object.new
      scope.instance_variable_set :@user, User.new
      template.render(scope)
    end.matches XML_INSTRUCT

    context "#object" do

      asserts "that it sets data source" do
        template = rabl %q{
          object @user
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals XML_INSTRUCT+"<user>\n</user>\n"

      asserts "that it can set root node" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals XML_INSTRUCT+"<person>\n</person>\n"

    end

  end

  context "with root node is true (old behavior)" do

    setup do
      Rabl.configure do |config|
        config.include_xml_root = true
      end
    end

    teardown do
      Rabl.reset_configuration!
    end

    context "#object" do
      asserts "that it sets data source as root" do
        template = rabl %q{
          object @user
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals XML_INSTRUCT+"<user>\n  <user>\n  </user>\n</user>\n"

      asserts "that it can set root node" do
        template = rabl %q{
          object @user => :person
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals XML_INSTRUCT+"<person>\n  <person>\n  </person>\n</person>\n"

    end

  end

  context "with root node as value" do

    teardown do
      Rabl.reset_configuration!
    end

    context "#object" do
      asserts "that it set root-node as symbol" do
        Rabl.configure do |config|
          config.include_xml_root = :root
        end
        template = rabl %q{
          object @user
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals XML_INSTRUCT+"<root>\n  <user>\n  </user>\n</root>\n"

      asserts "that it set root-node as string" do
        Rabl.configure do |config|
          config.include_xml_root = 'root'
        end
        template = rabl %q{
          object @user
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        template.render(scope)
      end.equals XML_INSTRUCT+"<root>\n  <user>\n  </user>\n</root>\n"

    end

  end

end
