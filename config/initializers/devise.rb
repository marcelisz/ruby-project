# frozen_string_literal: true

require "devise/orm/active_record"

Devise.setup do |config|
  config.parent_controller = "ApplicationController"
  config.mailer_sender = "no-reply@inventory.example"
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.sign_out_via = :delete
  config.navigational_formats = ["*/*", :html]
  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other

  config.omniauth :google_oauth2,
                  ENV.fetch("GOOGLE_CLIENT_ID", "google-client-id"),
                  ENV.fetch("GOOGLE_CLIENT_SECRET", "google-client-secret"),
                  scope: "email,profile",
                  prompt: "select_account"
  config.omniauth :facebook,
                  ENV.fetch("FACEBOOK_APP_ID", "facebook-app-id"),
                  ENV.fetch("FACEBOOK_APP_SECRET", "facebook-app-secret"),
                  scope: "email"
  config.omniauth :github,
                  ENV.fetch("GITHUB_CLIENT_ID", "github-client-id"),
                  ENV.fetch("GITHUB_CLIENT_SECRET", "github-client-secret"),
                  scope: "user:email"
end

OmniAuth.config.allowed_request_methods = [:post]
