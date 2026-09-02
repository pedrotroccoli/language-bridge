require "test_helper"

class Cli::AuthorizationsTest < ActionDispatch::IntegrationTest
  LOOPBACK = "http://127.0.0.1:53123/callback".freeze

  test "requires a signed-in user" do
    get cli_authorize_path(redirect_uri: LOOPBACK, state: "s")
    assert_redirected_to sign_in_path
  end

  test "shows the approval page for a valid loopback request" do
    sign_in_as(users(:admin))
    get cli_authorize_path(redirect_uri: LOOPBACK, state: "s", name: "laptop")
    assert_response :success
    assert_select "form"
  end

  test "flags a non-loopback callback" do
    sign_in_as(users(:admin))
    get cli_authorize_path(redirect_uri: "https://evil.example.com/steal", state: "s")
    assert_response :unprocessable_entity
  end

  test "approving mints a code and redirects to the loopback callback" do
    sign_in_as(users(:admin))
    assert_difference -> { CliAuthCode.count }, 1 do
      post cli_authorization_path, params: { redirect_uri: LOOPBACK, state: "xyz", name: "laptop" }
    end
    assert_response :redirect
    location = response.headers["Location"]
    assert location.start_with?("http://127.0.0.1:53123/callback")
    assert_match(/[?&]code=/, location)
    assert_match(/[?&]state=xyz/, location)
  end

  test "refuses to approve a non-loopback callback" do
    sign_in_as(users(:admin))
    assert_no_difference -> { CliAuthCode.count } do
      post cli_authorization_path, params: { redirect_uri: "https://evil.example.com", state: "s" }
    end
    assert_response :unprocessable_entity
  end
end
