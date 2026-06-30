require "test_helper"

class AccountControllerTest < ActionDispatch::IntegrationTest
  test "shows the signed-in user's account" do
    sign_in_as(users(:translator))
    get account_path
    assert_response :success
    assert_select "h1", "Account"
    assert_select "body", /#{users(:translator).email}/
  end

  test "updates the display name" do
    user = users(:translator)
    sign_in_as(user)

    patch account_path, params: { user: { name: "Grace Hopper" } }

    assert_redirected_to account_path
    assert_equal "Grace Hopper", user.reload.name
  end

  test "attaches an avatar" do
    user = users(:translator)
    sign_in_as(user)
    file = fixture_file_upload(file_fixture("avatar.png"), "image/png")

    patch account_path, params: { user: { avatar: file } }

    assert_redirected_to account_path
    assert user.reload.avatar.attached?
  end

  test "revokes all other sessions but keeps the current one" do
    user = users(:translator)
    other = user.sessions.create!(user_agent: "Old", ip_address: "1.2.3.4")
    sign_in_as(user)

    assert_difference -> { user.sessions.count }, -1 do
      delete account_sessions_path
    end
    assert_redirected_to account_path
    assert_not Session.exists?(other.id), "other session revoked"
    assert_equal 1, user.sessions.count, "current session kept"
  end
end
