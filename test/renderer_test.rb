require 'tmpdir'
require 'pathname'

context "Rabl::Renderer" do
  context "#render" do
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

      scope = Object.new
      user = User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new(source, nil, { :format => 'json', :locals => {:object => user} })
      renderer.render
    end.equals "{\"user\":{\"city\":\"irvine\"}}"

    helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }

    asserts 'loads source from file' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      user = User.new(:name => 'irvine')

      renderer = Rabl::Renderer.new('test', user, :view_path => tmp_path)
      renderer.render
    end.equals "{\"user\":{\"age\":24,\"name\":\"irvine\"}}"


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
      renderer.render
    end.equals "{\"user\":{\"age\":24,\"name\":\"irvine\"}}"

    asserts 'Rabl.render calls Renderer' do
      File.open(tmp_path + "test.json.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      user = User.new(:name => 'irvine')

      Rabl.render(user, 'test', :view_path => tmp_path)
    end.equals "{\"user\":{\"age\":24,\"name\":\"irvine\"}}"

  end
end
