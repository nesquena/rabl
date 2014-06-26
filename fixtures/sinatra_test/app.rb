require 'rubygems'
require 'sinatra'
require 'rabl'
require 'active_support/core_ext'
require 'active_support/inflector'
require 'active_record'
require 'builder'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database =>  ':memory:'
)

Dir[File.dirname(__FILE__) + "/models/*.rb"].each do |file|
  require File.expand_path(file)
end

# Register RABL
Rabl.configure do |config|
  config.perform_caching = true
end
Rabl.register!

class SinatraTest < Sinatra::Application
  set :root, File.expand_path(File.dirname(__FILE__))
  set :views, Proc.new { File.join(root, "views") }

  get "/posts" do
    @posts = Post.order("id ASC")
    render :rabl, :"posts/index", :format => "json"
  end

  get "/posts/:id" do
    @post = Post.find(params[:id])
    render :rabl, :"posts/show", :format => "json"
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

# Patch times to return as iso8601
class Time
  alias_method :old_to_s, :to_s
  def to_s(format=nil)
    format ? old_to_s(format) : iso8601
  end
end