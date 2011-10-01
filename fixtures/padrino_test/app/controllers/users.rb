PadrinoTest.controllers :users do
  get :index do
    @users = User.order("username ASC")
    render "users/index"
  end

  get :show, :map => "/users", :with => :id do
    @user = User.find(params[:id])
    render "users/show"
  end
end
