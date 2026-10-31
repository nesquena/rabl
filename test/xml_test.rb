# frozen_string_literal: true

require 'erb'
require 'active_support/core_ext/hash/conversions'
require 'active_support/time'
require 'tmpdir'

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

      # #581: each item is wrapped once, in the object root
      asserts "that it names items after :object_root without wrapping them twice" do
        template = rabl %{
          collection @users, :root => "data", :object_root => "TCCategory"
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'drinks'), User.new(:name => 'dining')]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<data type=\"array\">\n  <TCCategory>\n    <name>drinks</name>\n  </TCCategory>\n  <TCCategory>\n    <name>dining</name>\n  </TCCategory>\n</data>\n"

      asserts "that it does not repeat a root whose singular is itself" do
        template = rabl %{
          collection @users, :root => "list", :object_root => "trip"
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'one')]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<list type=\"array\">\n  <trip>\n    <name>one</name>\n  </trip>\n</list>\n"

      asserts "that it renders an empty collection with an object root" do
        template = rabl %{
          collection @users, :root => "data", :object_root => "TCCategory"
        }
        scope = Object.new
        scope.instance_variable_set :@users, []
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<data type=\"array\"/>\n"
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

      asserts "that it renders an array with its own to_xml with it" do
        template = rabl %{
          code(:tags) { @tags }
        }
        tags = Class.new(Array) { def to_xml(options = {}); options[:builder].tag!(options[:root], join(',')); end }
        scope = Object.new
        scope.instance_variable_set :@tags, tags.new(%w(a b))
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<hash>\n  <tags>a,b</tags>\n</hash>\n"
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

      # #725: the :root form keeps its key like the hash form does
      asserts "that it keeps a child named by :root when the collection is empty or nil" do
        [[], nil].map do |users|
          [%{child(@users, :root => :people) { attribute :city }},
           %{child(@users => :people) { attribute :city }}].map do |child_line|
            template = rabl "object @user\nattribute :name\n#{child_line}\n"
            scope = Object.new
            scope.instance_variable_set :@user, User.new(:name => 'leo', :city => 'LA')
            scope.instance_variable_set :@users, users
            template.render(scope)
          end
        end
      end.equals [["<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <name>leo</name>\n  <people type=\"array\"/>\n</user>\n"] * 2,
                  ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <name>leo</name>\n  <people nil=\"true\"/>\n</user>\n"] * 2]
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

    # #559: items are named with the app's inflections, which are defined in underscored form
    context "with an inflection defined by the app" do
      helper(:inflections) { ActiveSupport::Inflector.inflections(:en) }

      setup do
        @saved_rules = [inflections.plurals.dup, inflections.singulars.dup]
        inflections.irregular 'lesson_progress', 'lessons_progresses'
        inflections.irregular 'lesson-note', 'lessons-notes' # the workaround in #559
      end

      asserts "that it names collection items with it" do
        template = rabl %{
          collection @users => :lessons_progresses
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'intro')]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<lessons-progresses type=\"array\">\n  <lesson-progress>\n    <name>intro</name>\n  </lesson-progress>\n</lessons-progresses>\n"

      asserts "that it names child collection items with it" do
        template = rabl %{
          object @user
          child(@users => :lessons_progresses) { attribute :name }
        }
        scope = Object.new
        scope.instance_variable_set :@user, User.new
        scope.instance_variable_set :@users, [User.new(:name => 'intro')]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <lessons-progresses type=\"array\">\n    <lesson-progress>\n      <name>intro</name>\n    </lesson-progress>\n  </lessons-progresses>\n</user>\n"

      asserts "that it names the items of an array from a node with it" do
        template = rabl %{
          object false
          node(:lessons_progresses) { [{ :name => 'intro' }] }
        }
        template.render(Object.new)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<hash>\n  <lessons-progresses type=\"array\">\n    <lesson-progress>\n      <name>intro</name>\n    </lesson-progress>\n  </lessons-progresses>\n</hash>\n"

      asserts "that it names camelized items with it" do
        template = rabl %{
          collection @users => :lessons_progresses
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'intro')]
        begin
          Rabl.configuration.xml_options = { :camelize => :lower }
          template.render(scope)
        ensure
          Rabl.configuration.xml_options = {}
        end
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<lessonsProgresses type=\"array\">\n  <lessonProgress>\n    <name>intro</name>\n  </lessonProgress>\n</lessonsProgresses>\n"

      asserts "that it keeps names from an inflection written with dashes" do
        template = rabl %{
          collection @users => :lessons_notes
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'intro')]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<lessons-notes type=\"array\">\n  <lesson-note>\n    <name>intro</name>\n  </lesson-note>\n</lessons-notes>\n"

      # ActiveSupport finds an uncountable word at the end of a name only after a dash
      asserts "that it keeps names that end in an uncountable word" do
        template = rabl %{
          collection @users => :animal_species
          attribute :name
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new(:name => 'cat')]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<animal-species type=\"array\">\n  <animal-species>\n    <name>cat</name>\n  </animal-species>\n</animal-species>\n"

      teardown do
        inflections.plurals.replace(@saved_rules[0])
        inflections.singulars.replace(@saved_rules[1])
      end
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

      # An explicit :object_root names each item once (#581); before, Array#to_xml
      # wrapped every { "person" => ... } item in another <person>.
      asserts "that it sets root node for objects with :root parameter" do
        template = rabl %{
          collection @users, :root => :people, :object_root => :person
        }
        scope = Object.new
        scope.instance_variable_set :@users, [User.new, User.new]
        template.render(scope)
      end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<people type=\"array\">\n  <person>\n  </person>\n  <person>\n  </person>\n</people>\n"

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

  context "with escape_all_output" do
    setup do
      Rabl.configure { |config| config.escape_all_output = true }
    end

    asserts "that it escapes child values once, like top level values" do
      template = rabl %{
        object @user
        attribute :name
        child(@user => :person) { attribute :city }
      }
      scope = Object.new
      scope.instance_variable_set :@user, User.new(:name => 'a&b', :city => 'c&d')
      template.render(scope)
    end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <name>a&amp;amp;b</name>\n  <person>\n    <city>c&amp;amp;d</city>\n  </person>\n</user>\n"

    teardown do
      Rabl.reset_configuration!
    end
  end

  context "with xml_options set after rendering" do
    asserts "that it renders with the xml_options set last" do
      template = rabl %{
        object @user
        attribute :first_pets_name
      }
      scope = Object.new
      scope.instance_variable_set :@user, User.new(:first_pets_name => 'jack')
      template.render(scope)
      Rabl.configuration.xml_options = { :dasherize => false }
      template.render(scope)
    end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<user>\n  <first_pets_name>jack</first_pets_name>\n</user>\n"

    teardown do
      Rabl.reset_configuration!
    end
  end

  # A fresh process, since this suite loads ActiveSupport's XML conversions itself
  context "outside Rails" do
    helper(:render_xml_in_new_process) do |load_path|
      code = "require 'rabl'; Post = Struct.new(:title); " \
             "print Rabl::Renderer.xml(Post.new('a'), %{object @post\\nattribute :title\\n})"
      args = [RbConfig.ruby]
      args += ['-I', load_path] if load_path
      args += ['-I', File.expand_path('../../lib', __FILE__), '-e', code, { :err => [:child, :out] }]
      IO.popen(args) { |io| io.read }
    end

    asserts "that it loads what it needs to render XML" do
      render_xml_in_new_process(nil)
    end.matches %r{<post>\s*<title>a</title>\s*</post>}

    # In a new process too, since an acronym can't be undone
    asserts "that it keeps camelized names with an acronym" do
      code = "require 'rabl'; Post = Struct.new(:title); " \
             "ActiveSupport::Inflector.inflections(:en) { |inflect| inflect.acronym 'ID' }; " \
             "Rabl.configuration.xml_options = { :camelize => :lower }; " \
             "print Rabl::Renderer.xml([Post.new('a')], %{collection @posts => :user_ids\\nattribute :title\\n})"
      args = [RbConfig.ruby, '-I', File.expand_path('../../lib', __FILE__), '-e', code, { :err => [:child, :out] }]
      IO.popen(args) { |io| io.read }
    end.matches %r{<userIds type="array">\s*<userId>\s*<title>a</title>\s*</userId>\s*</userIds>}

    asserts "that it explains a missing builder gem" do
      Dir.mktmpdir do |without_builder|
        File.open(File.join(without_builder, 'builder.rb'), 'w') { |f| f.puts 'raise LoadError, "cannot load such file -- builder"' }
        render_xml_in_new_process(without_builder)
      end
    end.matches %r{rabl needs the builder gem to render XML}
  end
end
