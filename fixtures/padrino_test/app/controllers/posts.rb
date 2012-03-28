PadrinoTest.controllers :posts do
  get :index do
    @posts = Post.order("id ASC")
    render :rabl, "posts/index"
  end

  get :show, :map => "/posts", :with => :id do
    @post = Post.find(params[:id])
    render :rabl, "posts/show"
  end
end
