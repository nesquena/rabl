class PostsController < ApplicationController
  respond_to :json

  def index
    @posts = Post.all(:order => "id ASC")
  end

  def show
    @post = Post.find(params[:id])
  end
end
