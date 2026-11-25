require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "oauth-123",
      info: { email: "oauth@example.com", name: "OAuth User" }
    )
  end

  teardown do
    OmniAuth.config.mock_auth = {}
    OmniAuth.config.test_mode = false
  end

  test "external account creates and signs in a user" do
    assert_difference(["User.count", "Identity.count"], 1) do
      post user_google_oauth2_omniauth_authorize_path
      follow_redirect!
      follow_redirect!
    end

    assert_equal root_path, path
    user = User.find_by!(email: "oauth@example.com")
    assert_equal "OAuth User", user.name
    assert_equal "google_oauth2", user.identities.first.provider

    get root_path
    assert_response :success
    assert_select "button", text: /OAuth User/
  end

  test "a blocked external account cannot sign in" do
    blocked = User.create!(name: "Blocked", email: "oauth@example.com", blocked_at: Time.current)

    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!
    follow_redirect!

    assert_equal new_user_session_path, path
    assert_equal blocked.id, User.find_by!(email: "oauth@example.com").id
    assert_equal 0, blocked.identities.count
  end

  test "logout ends the session" do
    user = User.create!(name: "Logged In", email: "logged@example.com")
    sign_in user

    delete destroy_user_session_path
    assert_redirected_to root_path
    get root_path
    assert_select "a", text: I18n.t("header.log_in")
  end
end
