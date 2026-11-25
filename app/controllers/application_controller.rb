class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale
  before_action :set_theme
  before_action :reject_blocked_user

  helper_method :current_theme

  private

  def set_locale
    locale = current_user&.language.presence || cookies[:language] || I18n.default_locale
    I18n.locale = I18n.available_locales.map(&:to_s).include?(locale.to_s) ? locale.to_sym : I18n.default_locale
  end

  def set_theme
    theme = current_user&.theme.presence || cookies[:theme] || "light"
    @current_theme = User::THEMES.include?(theme.to_s) ? theme.to_s : "light"
  end

  def current_theme
    @current_theme
  end

  def reject_blocked_user
    return unless user_signed_in? && current_user.blocked?

    sign_out(current_user)
    redirect_to new_user_session_path, alert: t("auth.blocked")
  end

  def require_admin!
    return if current_user&.admin?

    redirect_to root_path, alert: t("flash.not_authorized")
  end

  def require_inventory_manager!
    return if @inventory.manageable_by?(current_user)

    redirect_to inventory_path(@inventory), alert: t("flash.not_authorized")
  end

  def require_inventory_writer!
    return if @inventory.writable_by?(current_user)

    redirect_to inventory_path(@inventory), alert: t("flash.not_authorized")
  end

  def after_sign_in_path_for(_resource)
    root_path
  end

  def after_sign_out_path_for(_scope)
    root_path
  end
end
