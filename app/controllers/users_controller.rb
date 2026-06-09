# Admin user management. Once registration is closed (after the first account),
# this is how new accounts are created. Shared install: any signed-in user can add
# or remove accounts. You can't remove yourself or the last remaining account.
class UsersController < ApplicationController
  before_action :set_user, only: :destroy

  def index
    @users = User.order(:email_address)
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "Account created for #{@user.email_address}."
    else
      @users = User.order(:email_address)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == Current.user
      redirect_to users_path, alert: "You can't remove your own account."
    elsif User.count <= 1
      redirect_to users_path, alert: "You can't remove the last account."
    else
      @user.destroy
      redirect_to users_path, notice: "Account removed."
    end
  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email_address, :password, :password_confirmation)
    end
end
