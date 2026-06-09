# Account sign-up, restricted for public deployments: open ONLY until the first
# account exists (bootstraps the initial admin on a fresh deploy). Once any user
# exists, registration is closed and further accounts are created by an existing
# user from the Users admin page (shared install: every account is an admin).
class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]
  before_action :ensure_registration_open, only: [ :new, :create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url, notice: "Welcome to ghrian."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def ensure_registration_open
      return unless User.exists?

      redirect_to new_session_path, alert: "Registration is closed. Ask an admin to create your account."
    end

    def registration_params
      params.require(:user).permit(:email_address, :password, :password_confirmation)
    end
end
