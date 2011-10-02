class UsersController < ApplicationController
  respond_to :json

  def index
    @users = User.all(:order => "username ASC")
  end

  def show
    @user = User.find(params[:id])
  end
end
