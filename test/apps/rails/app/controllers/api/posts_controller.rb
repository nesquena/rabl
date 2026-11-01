# An API-mode controller: rabl's railtie lets ActionController::API render templates
class Api::PostsController < ActionController::API
  def show
    @post = Post.find(params[:id])
  end
end
