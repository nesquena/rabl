class UsersController < ApplicationController
  def index
    @users = User.order('username ASC').load
  end

  def show
    @user = User.find(params[:id])
  end
end
