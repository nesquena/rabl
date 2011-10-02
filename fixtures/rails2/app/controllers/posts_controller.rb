class PostsController < ApplicationController
  def index
    @posts = Post.all(:order => "id ASC")
    respond_to do |format|
      format.json { render "posts/index" }
    end
  end

  def show
    @post = Post.find(params[:id])
    respond_to do |format|
      format.json { render "posts/show" }
    end
  end
end
