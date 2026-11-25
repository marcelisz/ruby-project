module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def google_oauth2
      authenticate_from_oauth
    end

    def facebook
      authenticate_from_oauth
    end

    def github
      authenticate_from_oauth
    end

    def failure
      redirect_to new_user_session_path, alert: t("auth.failure")
    end

    private

    def authenticate_from_oauth
      auth = request.env["omniauth.auth"]
      return redirect_to(new_user_session_path, alert: t("auth.failure")) if auth.blank?

      identity = Identity.find_by(provider: auth.provider, uid: auth.uid)
      user = identity&.user || User.find_by(email: email_from(auth))

      if user&.blocked?
        redirect_to new_user_session_path, alert: t("auth.blocked")
        return
      end

      user = create_user(auth) unless user
      identity ||= user.identities.create!(provider: auth.provider, uid: auth.uid)

      flash[:notice] = t("auth.success")
      sign_in_and_redirect(user, event: :authentication)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to new_user_session_path, alert: t("auth.failure")
    end

    def create_user(auth)
      info = auth.info
      User.create!(
        email: email_from(auth),
        name: info.name.presence || info.nickname.presence || email_from(auth).split("@").first
      )
    end

    def email_from(auth)
      auth.info.email.presence&.downcase ||
        "#{auth.provider}-#{auth.uid.to_s.gsub(/[^a-zA-Z0-9]/, "")}@users.example.com"
    end
  end
end
