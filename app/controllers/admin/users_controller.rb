module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    def index
      @users = User.order(:name)
    end

    def block
      user = User.find(params[:id])
      user.update!(blocked_at: Time.current)
      if user == current_user
        sign_out(current_user)
        redirect_to root_path, notice: t("admin.users.blocked")
      else
        redirect_to admin_path, notice: t("admin.users.blocked")
      end
    end

    def unblock
      User.find(params[:id]).update!(blocked_at: nil)
      redirect_to admin_path, notice: t("admin.users.unblocked")
    end

    def toggle_admin
      user = User.find(params[:id])
      user.update!(admin: !user.admin?)
      redirect_to(user == current_user ? user_path(user) : admin_path,
                  notice: t("admin.users.role_updated"))
    end

    def destroy
      user = User.find(params[:id])
      self_delete = user == current_user
      sign_out(current_user) if self_delete
      user.destroy!
      redirect_to(self_delete ? root_path : admin_path, notice: t("admin.users.deleted"))
    end
  end
end
