module Users
  class SessionsController < ApplicationController
    layout "auth"

    def new
      redirect_to root_path if user_signed_in?
    end

    def destroy
      sign_out(current_user)
      redirect_to root_path, notice: t("auth.signed_out")
    end
  end
end
