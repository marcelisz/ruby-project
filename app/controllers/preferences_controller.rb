class PreferencesController < ApplicationController
  def language
    locale = params[:locale].to_s
    return head :unprocessable_content unless User::LANGUAGES.include?(locale)

    persist(:language, locale)
    redirect_back fallback_location: root_path, allow_other_host: false
  end

  def theme
    theme = params[:theme].to_s
    return head :unprocessable_content unless User::THEMES.include?(theme)

    persist(:theme, theme)
    redirect_back fallback_location: root_path, allow_other_host: false
  end

  private

  def persist(key, value)
    cookies.permanent[key] = value
    current_user&.update_column(key, value)
  end
end
