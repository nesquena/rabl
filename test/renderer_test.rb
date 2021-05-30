require 'tmpdir'
require 'pathname'
require 'json'
require File.expand_path('../teststrap', __FILE__)

context "Rabl::Renderer" do
  helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }
  # context_scope 'users', [@user]
  helper(:context_scope) { |name, value|
    scope = Object.new
    stub(scope).controller { stub(Object).controller_name { name } }
    scope.instance_variable_set :"@#{name.pluralize}", nil
    scope.instance_variable_set :"@#{name}", value
    scope
  }

  context "#render" do
    asserts 'renders empty array' do
      source = %q{
        collection @users
        attribute :name, :as => 'city'
      }

      scope = Object.new
      scope.instance_variable_set :@users, []

      renderer = Rabl::Renderer.new(source, [], { :format => 'json', :root => true, :view_path => '/path/to/views', :scope => scope })
      renderer.render
    end.equals "[]"

    asserts 'renders string as source' do
      source = %q{
        object @user
        attribute :name, :as => 'city'
      }

      user = User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new(source, user, { :format => 'json', :root => true, :view_path => '/path/to/views' })
      JSON.parse(renderer.render)
    end.equals JSON.parse("{\"user\":{\"city\":\"irvine\"}}")

    asserts 'allows redirecting scope to another object' do
      source = %q{
        object @user
        attribute :name, :as => 'city'
      }

      scope = Object.new
      scope.instance_variable_set :@user, User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new(source, nil, { :format => 'json', :scope => scope })
      JSON.parse(renderer.render)
    end.equals JSON.parse("{\"user\":{\"city\":\"irvine\"}}")

    asserts 'accepts scope on render' do
      source = %q{
        object @user
        attribute :name, :as => 'city'
      }

      scope = Object.new
      scope.instance_variable_set :@user, User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new(source)
      JSON.parse(renderer.render(scope))
    end.equals JSON.parse("{\"user\":{\"city\":\"irvine\"}}")

    asserts 'passes :locals to render' do
      source = %q{
        attribute :name, :as => 'city'
        node(:zipcode) { @zipcode }
      }

      user = User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new(source, nil, { :format => 'json', :locals => {:object => user, :zipcode => "92602"} })
      JSON.parse(renderer.render)
    end.equals JSON.parse("{\"user\":{\"city\":\"irvine\",\"zipcode\":\"92602\"}}")

    asserts 'loads source from file' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      user = User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new('test', user, :view_path => tmp_path)
      JSON.parse(renderer.render)
    end.equals JSON.parse("{\"user\":{\"age\":24,\"name\":\"irvine\"}}")

    asserts 'uses globally configured view paths' do
      Rabl.configure do |config|
        config.view_paths << tmp_path
      end

      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts %q{
          attributes :age
        }
      end

      user = User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new('test', user)
      JSON.parse(renderer.render)
    end.equals JSON.parse("{\"user\":{\"age\":24,\"name\":\"irvine\"}}")

    asserts 'handles paths for extends' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          attributes :age
        }
      end

      File.open(tmp_path + "user.json.rabl", "w") do |f|
        f.puts %(
          object @user
          attribute :name
          extends 'test'
        )
      end

      user = User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new('user', user, :view_path => tmp_path)
      JSON.parse(renderer.render)
    end.equals JSON.parse("{\"user\":{\"age\":24,\"name\":\"irvine\"}}")


    asserts 'handles extends with child as nil' do
      File.open(tmp_path + "foo.json.rabl", "w") do |f|
        f.puts %q{
          object @foo
          node(:test) do |foo|
            {
              test: "#{foo.attribute}"
            }
          end
        }
      end

      File.open(tmp_path + "bar.json.rabl", "w") do |f|
        f.puts %q{
          object false
          node do
            {
              test_attribute: 'test_value'
            }
          end
          child(@foos => :foo_collection) do
            extends 'foo'
          end
        }
      end

      sc = Object.new
      sc.instance_variable_set :@foos, nil
      renderer = Rabl::Renderer.new('bar', false, :view_path => tmp_path, :scope => sc)
      JSON.parse(renderer.render)
    end.equals JSON.parse("{\"test_attribute\":\"test_value\", \"foo_collection\":null}")

    asserts 'handles extends with custom node and object set false' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          node(:foo) { 'baz' }
        }
      end

      File.open(tmp_path + "user.json.rabl", "w") do |f|
        f.puts %(
          object false
          node(:baz) { "bar" }
          extends 'test'
        )
      end

      scope = context_scope('users', [User.new, User.new, User.new])
      renderer = Rabl::Renderer.new('user', false, :view_path => tmp_path, :scope => scope)
      JSON.parse(renderer.render)
    end.equals(JSON.parse(%Q^{"foo":"baz", "baz":"bar" }^))

    asserts 'handles extends with attributes and object set false' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          attributes :foo, :bar, :baz
          node(:test) { |bar| bar.demo if bar }
        }
      end

      File.open(tmp_path + "user.json.rabl", "w") do |f|
        f.puts %(
          object false
          extends 'test'
        )
      end

      renderer = Rabl::Renderer.new('user', false, :view_path => tmp_path)
      JSON.parse(renderer.render)
    end.equals(JSON.parse(%Q^{"test": null}^))

    # FIXME template is found and rendered but not included in final results
    # asserts 'handles paths for partial' do
    #   File.open(tmp_path + "test.json.rabl", "w") do |f|
    #     f.puts %q{
    #       attributes :age
    #     }
    #   end

    #   File.open(tmp_path + "user.json.rabl", "w") do |f|
    #     f.puts %(
    #       object @user
    #       attribute :name
    #       partial 'test', :object => @user
    #     )
    #   end

    #   user = User.new(:name => 'irvine')

    #   renderer = Rabl::Renderer.new('user', user, :view_path => tmp_path)
    #   JSON.parse(renderer.render)
    # end.equals JSON.parse("{\"user\":{\"age\":24,\"name\":\"irvine\"}}")

    asserts 'Rabl.render calls Renderer' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      user = User.new(:name => 'irvine')

      JSON.parse(Rabl.render(user, 'test', :view_path => tmp_path))
    end.equals JSON.parse("{\"user\":{\"age\":24,\"name\":\"irvine\"}}")

    asserts 'it renders collections' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          collection @users => :users
          attributes :age, :name
        }
      end

      sc = Object.new
      sc.instance_variable_set :@users, nil
      Rabl.render([], 'test', :view_path => tmp_path, :scope => sc)
    end.equals "{\"users\":[]}"

    asserts 'it renders an array when given an empty collection' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          collection @users
          attribute :name, :age
        }
      end

      scope = Object.new
      scope.instance_variable_set :@users, nil
      Rabl.render([], 'test', :view_path => tmp_path, :root => false, :scope => scope)
    end.equals "[]"

    asserts 'handles view path for when it specified and config is empty' do
      Rabl.configuration.view_paths = []

      File.open(tmp_path + "profile.json.rabl", "w") do |f|
        f.puts %q{
          attributes :gender
        }
      end

      File.open(tmp_path + "user.json.rabl", "w") do |f|
        f.puts %(
          object @user
          attribute :name
          glue(:profile) do
            extends 'profile'
          end
          child(:profile) do
            extends 'profile'
          end
        )
      end

      user = User.new(:name => 'irvine')
      stub(user).profile { stub!.gender { "male" } }

      renderer = Rabl::Renderer.new('user', user, :view_path => tmp_path)
      JSON.parse(renderer.render)
    end.equals JSON.parse("{\"user\":{\"name\":\"irvine\",\"object\":{\"gender\":\"male\"},\"gender\":\"male\"}}")


    asserts "it renders for object false" do
      File.open(tmp_path + "test2.rabl", "w") do |f|
        f.puts %q{
          object false
          node(:foo) { 'bar' }
        }
      end

      user = User.new(:name => 'ivan')
      JSON.parse(Rabl.render(user, 'test2', :view_path => tmp_path))
    end.equals JSON.parse("{\"foo\":\"bar\"}")

    asserts "it renders for object key specified in template" do
      File.open(tmp_path + "test3.rabl", "w") do |f|
        f.puts %q{
          object @user => :person
          attributes :age, :name
        }
      end

      user = User.new(:name => 'ivan')
      JSON.parse(Rabl.render(user, 'test3', :view_path => tmp_path))
    end.equals JSON.parse("{\"person\":{\"age\":24,\"name\":\"ivan\"} }")

    asserts "it renders for overwriting object key specified in render" do
      File.open(tmp_path + "test4.rabl", "w") do |f|
        f.puts %q{
          object @user => :person
          attributes :age, :name
        }
      end

      sc = Object.new
      sc.instance_variable_set :@user, nil
      user = User.new(:name => 'ivan')
      JSON.parse(Rabl.render({ user => :human }, 'test4', :view_path => tmp_path, :scope => sc))
    end.equals JSON.parse("{\"human\":{\"age\":24,\"name\":\"ivan\"} }")

    asserts "it renders for specific object key passed to render" do
      File.open(tmp_path + "test5.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      sc = Object.new
      sc.instance_variable_set :@user, nil
      user = User.new(:name => 'ivan')
      JSON.parse(Rabl.render({ user => :person }, 'test5', :view_path => tmp_path, :scope => sc))
    end.equals JSON.parse("{\"person\":{\"age\":24,\"name\":\"ivan\"} }")
  end # render

  context '.json' do
    asserts 'it renders json' do
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name, :float
        }
      end

      user = User.new(:name => 'ivan')
      JSON.parse(Rabl::Renderer.json(user, 'test', :view_path => tmp_path))
    end.equals JSON.parse("{\"user\":{\"age\":24,\"name\":\"ivan\",\"float\":1234.56}}")
  end # json

  context '.msgpack' do
    asserts 'it renders msgpack' do
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name, :float
        }
      end

      user = User.new(:name => 'ivan')
      char_split Rabl::Renderer.msgpack(user, 'test', :view_path => tmp_path)
    end.equals char_split("\x81\xA4user\x83\xA3age\x18\xA4name\xA4ivan\xA5float\xCB@\x93J=p\xA3\xD7\n")
  end

  context '.plist' do
    asserts 'it renders xml' do
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name, :float
        }
      end

      user = User.new(:name => 'ivan')
      Rabl::Renderer.plist(user, 'test', :view_path => tmp_path)
    end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t<key>user</key>\n\t<dict>\n\t\t<key>age</key>\n\t\t<integer>24</integer>\n\t\t<key>float</key>\n\t\t<real>1234.56</real>\n\t\t<key>name</key>\n\t\t<string>ivan</string>\n\t</dict>\n</dict>\n</plist>\n"
  end
end
