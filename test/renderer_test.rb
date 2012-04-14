require 'tmpdir'
require 'pathname'

context "Rabl::Renderer" do
  helper(:tmp_path) { @tmp_path ||= Pathname.new(Dir.mktmpdir) }
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

  context '.json' do
    asserts 'it renders json' do
      File.open(tmp_path + "test.rabl", "w") do |f|
        f.puts %q{
          object @user
          attributes :age, :name
        }
      end

      user = User.new(:name => 'ivan')
      Rabl::Renderer.json(user, 'test', :view_path => tmp_path)
    end.equals "{\"user\":{\"age\":24,\"name\":\"ivan\"}}"
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
