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

  test "shows the requested capabilities and mints a code carrying them" do
    sign_in_as(users(:admin))
    get cli_authorize_path(redirect_uri: LOOPBACK, state: "s", name: "laptop", scopes: %w[ read write ])
    assert_response :success
    assert_includes response.body, "Read published"

    assert_difference -> { CliAuthCode.count }, 1 do
      post cli_authorization_path, params: { redirect_uri: LOOPBACK, state: "s", name: "laptop", scopes: %w[ read write ] }
    end
    assert_equal %w[ read write ], CliAuthCode.last.scopes
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

  test "shows the verification code the CLI derives from state" do
    sign_in_as(users(:admin))
    get cli_authorize_path(redirect_uri: LOOPBACK, state: "xyz", name: "laptop")
    # Literal vector, mirrored in the CLI's login test: pins the wire format so
    # either side drifting from SHA-256/8-hex/upcase/dash-at-4 fails a suite.
    assert_includes response.body, "3608-BCA1"
  end

  test "flags a request without state — no code for the user to verify" do
    sign_in_as(users(:admin))
    get cli_authorize_path(redirect_uri: LOOPBACK, name: "laptop")
    assert_response :unprocessable_entity

    assert_no_difference -> { CliAuthCode.count } do
      post cli_authorization_path, params: { redirect_uri: LOOPBACK, name: "laptop" }
    end
    assert_response :unprocessable_entity
  end

  test "never grants admin, even when the URL asks for it" do
    sign_in_as(users(:admin))
    get cli_authorize_path(redirect_uri: LOOPBACK, state: "s", name: "laptop", scopes: %w[ read admin ])
    assert_response :success

    post cli_authorization_path, params: { redirect_uri: LOOPBACK, state: "s", name: "laptop", scopes: %w[ read admin ] }
    assert_equal %w[ read ], CliAuthCode.last.scopes
  end

  test "rejecting bounces back to the loopback with access_denied and mints nothing" do
    sign_in_as(users(:admin))
    assert_no_difference -> { CliAuthCode.count } do
      get cli_authorization_rejection_path(redirect_uri: LOOPBACK, state: "xyz")
    end
    assert_response :redirect
    location = response.headers["Location"]
    assert location.start_with?("http://127.0.0.1:53123/callback")
    assert_match(/[?&]error=access_denied/, location)
    assert_match(/[?&]state=xyz/, location)
  end

  test "rejecting without a loopback renders the standalone confirmation" do
    sign_in_as(users(:admin))
    get cli_authorization_rejection_path
    assert_response :success
    assert_includes response.body, "Request rejected"
  end

  test "refuses to approve a non-loopback callback" do
    sign_in_as(users(:admin))
    assert_no_difference -> { CliAuthCode.count } do
      post cli_authorization_path, params: { redirect_uri: "https://evil.example.com", state: "s" }
    end
    assert_response :unprocessable_entity
  end
end
