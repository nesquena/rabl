require File.expand_path('../teststrap', __FILE__)
require File.expand_path('../../lib/rabl', __FILE__)
require File.expand_path('../../lib/rabl/template', __FILE__)
require File.expand_path('../models/user', __FILE__)

context "Rabl::Engine" do
  helper(:rabl) { |t| RablTemplate.new("code", :format => 'csv') { t } }

  context "with csv defaults" do
    setup do
      Rabl.configure do |config|
        
      end
    end

    context "#attribute" do
      asserts "that it adds attributes or method to be included in output" do
        template = rabl %{
          collection @users
          attribute :name, :age
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'Arr', :age => 25), User.new(:name => 'Byy', :age => 12)]
        template.render(scope)
      end.equals "name,age\nArr,25\nByy,12\n"

      asserts "that it can add attributes under a different key name through :as" do
        template = rabl %{
          collection @users
          attribute :name, :as => :first_name
          attribute :age
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'Arr', :age => 25), User.new(:name => 'Byy', :age => 12)]
        template.render(scope)
      end.equals "first_name,age\nArr,25\nByy,12\n"

      asserts "that it can add attributes under a different key name through hash" do
        template = rabl %{
          collection @users
          attribute :name => :first_name
          attribute :age
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'Arr', :age => 25), User.new(:name => 'Byy', :age => 12)]
        template.render(scope)
      end.equals "first_name,age\nArr,25\nByy,12\n"
    end

    context "#child" do
      asserts "that it can create a node" do
        template = rabl %{
          collection @users

          attribute :city
          node (:name) { |user| user.first + " " + user.name }
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:first => "Asd", :name => 'Mir'), User.new(:first => "Sdw", :name => 'Sqq')]
        template.render(scope)
      end.equals "city,name\nirvine,Asd Mir\nirvine,Sdw Sqq\n"

      asserts "that it can create a node with different key" do
        template = rabl %{
          collection @users

          attribute :city
          node (:full_name) { |user| user.first + " " + user.name }
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:first => "Asd", :name => 'Mir'), User.new(:first => "Sdw", :name => 'Sqq')]
        template.render(scope)
      end.equals "city,full_name\nirvine,Asd Mir\nirvine,Sdw Sqq\n"

      asserts "that it can create a conditional node" do
        template = rabl %{
          collection @users

          attribute :city
          node :full_name, :if => lambda { |u| false } do |user| 
            user.first + " " + user.name
          end
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:first => "Asd", :name => 'Mir'), User.new(:first => "Sdw", :name => 'Sqq')]
        template.render(scope)
      end.equals "city\nirvine\nirvine\n"
    end

    teardown do
      Rabl.reset_configuration!
    end
  end

  context "with csv config" do
    setup do
      Rabl.configure do |config|
        config.csv_options = { :col_sep  => ';', :row_sep => '||' }
      end
    end

    context "#attribute" do
      asserts "that it adds attributes or method to be included in output" do
        template = rabl %{
          collection @users
          attribute :name, :age
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'Arr', :age => 25), User.new(:name => 'Byy', :age => 12)]
        template.render(scope)
      end.equals "name;age||Arr;25||Byy;12||"

      asserts "that it can add attributes under a different key name through :as" do
        template = rabl %{
          collection @users
          attribute :name, :as => :first_name
          attribute :age
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'Arr', :age => 25), User.new(:name => 'Byy', :age => 12)]
        template.render(scope)
      end.equals "first_name;age||Arr;25||Byy;12||"

      asserts "that it can add attributes under a different key name through hash" do
        template = rabl %{
          collection @users
          attribute :name => :first_name
          attribute :age
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'Arr', :age => 25), User.new(:name => 'Byy', :age => 12)]
        template.render(scope)
      end.equals "first_name;age||Arr;25||Byy;12||"
    end

    context "#child" do
      asserts "that it can create a node" do
        template = rabl %{
          collection @users

          attribute :city
          node (:name) { |user| user.first + " " + user.name }
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:first => "Asd", :name => 'Mir'), User.new(:first => "Sdw", :name => 'Sqq')]
        template.render(scope)
      end.equals "city;name||irvine;Asd Mir||irvine;Sdw Sqq||"

      asserts "that it can create a node with different key" do
        template = rabl %{
          collection @users

          attribute :city
          node (:full_name) { |user| user.first + " " + user.name }
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:first => "Asd", :name => 'Mir'), User.new(:first => "Sdw", :name => 'Sqq')]
        template.render(scope)
      end.equals "city;full_name||irvine;Asd Mir||irvine;Sdw Sqq||"

      asserts "that it can create a conditional node" do
        template = rabl %{
          collection @users

          attribute :city
          node :full_name, :if => lambda { |u| false } do |user| 
            user.first + " " + user.name
          end
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:first => "Asd", :name => 'Mir'), User.new(:first => "Sdw", :name => 'Sqq')]
        template.render(scope)
      end.equals "city||irvine||irvine||"
    end

    teardown do
      Rabl.reset_configuration!
    end
  end
end
