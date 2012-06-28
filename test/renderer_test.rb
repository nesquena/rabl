require 'tmpdir'
require 'pathname'
require File.expand_path('../teststrap', __FILE__)
require File.expand_path('../../lib/rabl', __FILE__)

context "Rabl::Renderer" do
  helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

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
      renderer.render
    end.equals "{\"user\":{\"city\":\"irvine\"}}"

    asserts 'allows redirecting scope to another object' do
      source = %q{
        object @user
        attribute :name, :as => 'city'
      }

      scope = Object.new
      scope.instance_variable_set :@user, User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new(source, nil, { :format => 'json', :scope => scope })
      renderer.render
    end.equals "{\"user\":{\"city\":\"irvine\"}}"

    asserts 'accepts scope on render' do
      source = %q{
        object @user
        attribute :name, :as => 'city'
      }

      scope = Object.new
      scope.instance_variable_set :@user, User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new(source)
      renderer.render(scope)
    end.equals "{\"user\":{\"city\":\"irvine\"}}"

    asserts 'passes :locals to render' do
      source = %q{
        attribute :name, :as => 'city'
      }

      user = User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new(source, nil, { :format => 'json', :locals => {:object => user} })
      renderer.render.split("").sort
    end.equals "{\"user\":{\"city\":\"irvine\"}}".split("").sort

    asserts 'loads source from file' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      user = User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new('test', user, :view_path => tmp_path)
      renderer.render.split("").sort
    end.equals "{\"user\":{\"age\":24,\"name\":\"irvine\"}}".split("").sort

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
      renderer.render.split("").sort
    end.equals "{\"user\":{\"age\":24,\"name\":\"irvine\"}}".split("").sort


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
      renderer.render.split("").sort
    end.equals "{\"user\":{\"age\":24,\"name\":\"irvine\"}}".split("").sort

    asserts 'Rabl.render calls Renderer' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      user = User.new(:name => 'irvine')

      Rabl.render(user, 'test', :view_path => tmp_path).split("").sort
    end.equals "{\"user\":{\"age\":24,\"name\":\"irvine\"}}".split("").sort

    asserts 'it renders collections' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          collection @users => :users
          attributes :age, :name
        }
      end

      scope = Object.new
      scope.instance_variable_set :@users, nil
      Rabl.render([], 'test', :view_path => tmp_path, :scope => scope).split("").sort
    end.equals "{\"users\":[]}".split("").sort

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
      renderer.render.split("").sort
    end.equals "{\"user\":{\"name\":\"irvine\",\"object\":{\"gender\":\"male\"},\"gender\":\"male\"}}".split("").sort
  end

  context '.json' do
    asserts 'it renders json' do
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      user = User.new(:name => 'ivan')
      Rabl::Renderer.json(user, 'test', :view_path => tmp_path).split("").sort
    end.equals "{\"user\":{\"age\":24,\"name\":\"ivan\"}}".split("").sort
  end

  context '.msgpack' do
    asserts 'it renders msgpack' do
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      user = User.new(:name => 'ivan')
      Rabl::Renderer.msgpack(user, 'test', :view_path => tmp_path).split("").sort
    end.equals "\x81\xA4user\x82\xA3age\x18\xA4name\xA4ivan".split("").sort
  end

  context '.plist' do
    asserts 'it renders xml' do
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      user = User.new(:name => 'ivan')
      Rabl::Renderer.plist(user, 'test', :view_path => tmp_path)
    end.equals "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t<key>user</key>\n\t<dict>\n\t\t<key>age</key>\n\t\t<integer>24</integer>\n\t\t<key>name</key>\n\t\t<string>ivan</string>\n\t</dict>\n</dict>\n</plist>\n"
  end
end
