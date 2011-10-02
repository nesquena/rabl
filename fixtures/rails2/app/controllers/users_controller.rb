class UsersController < ApplicationController
  def index
    @users = User.all(:order => "username ASC")
    respond_to do |format|
      format.json { render "users/index" }
    end
  end

  def show
    @user = User.find(params[:id])
    respond_to do |format|
      format.json { render "users/show" }
    end
  end
end
