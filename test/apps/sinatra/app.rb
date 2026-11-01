require 'bundler/setup'
require 'sinatra/base'
require 'active_record'
require 'oj'
require 'rabl'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
ActiveRecord::Migration.verbose = false
Dir[File.join(__dir__, 'db/migrate/*.rb'), File.join(__dir__, 'app/models/*.rb')].sort.each { |file| require file }
CreateRablTestTables.migrate(:up)

Rabl.register!

class RablSinatraApp < Sinatra::Base
  set :root, __dir__
  set :views, File.join(root, 'app/views')

  helpers do
    def helper_foo
      "BAR!"
    end
  end

  get "/posts" do
    @posts = Post.order("id ASC")
    render :rabl, :"posts/index", :format => "json"
  end

  get "/posts/:id" do
    @post = Post.find(params[:id])
    render :rabl, :"posts/show", :format => "json"
  end

  get "/posts/:id/renderer" do
    post = Post.find(params[:id])
    Rabl.render(post, 'posts/renderer', :view_path => settings.views, :format => :json, :scope => self)
  end

  get "/users" do
    @users = User.order("username ASC")
    render :rabl, :"users/index.json", :format => "json"
  end

  get "/users/:id" do
    @user = User.find(params[:id])
    render :rabl, :"users/show.json", :format => "json"
  end
end
