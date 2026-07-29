require "test_helper"

class SignInFlowTest < ActionDispatch::IntegrationTest
  test "first user with empty users table becomes admin" do
    User.destroy_all

    assert_difference "User.count", 1 do
      post sign_in_path, params: { email: "founder@example.com" }
    end

    assert_equal "admin", User.find_by(email: "founder@example.com").role
    assert_redirected_to sign_in_path
  end

  test "subsequent unknown email is rejected after bootstrap" do
    assert_no_difference "User.count" do
      post sign_in_path, params: { email: "stranger@example.com" }
    end
    assert_redirected_to sign_in_path
    follow_redirect!
    assert_match(/Ask an admin/, flash[:alert])
  end

  test "existing user receives magic link email" do
    assert_emails 1 do
      perform_enqueued_jobs do
        post sign_in_path, params: { email: users(:admin).email }
      end
    end
  end

  test "valid magic link signs in user" do
    token = users(:admin).sign_in_tokens.create!
    get sign_in_with_token_path(token: token.token)
    assert_redirected_to root_path
    assert_nil SignInToken.find_by(id: token.id), "token should be consumed"
  end

  test "expired magic link is rejected" do
    token = users(:admin).sign_in_tokens.create!(expires_at: 1.hour.ago)
    get sign_in_with_token_path(token: token.token)
    assert_redirected_to sign_in_path
  end

  test "sign out destroys session" do
    sign_in_as(users(:admin))
    assert_difference "Session.count", -1 do
      delete sign_out_path
    end
    assert_redirected_to sign_in_path
  end

  private
    def sign_in_as(user)
      token = user.sign_in_tokens.create!
      get sign_in_with_token_path(token: token.token)
    end
end
