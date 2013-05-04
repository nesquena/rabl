class PostsController < ApplicationController
  respond_to :json, :xml, :html, :rabl_test_v1

  def index
    @posts = Post.order('id ASC').load
  end

  def show
    @post = Post.find(params[:id])
  end
end
