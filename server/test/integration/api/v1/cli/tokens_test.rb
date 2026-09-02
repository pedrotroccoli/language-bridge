require "test_helper"

class Api::V1::Cli::TokensTest < ActionDispatch::IntegrationTest
  test "exchanges a valid code for a freshly-minted token" do
    raw = CliAuthCode.issue(user: users(:translator), name: "laptop")

    assert_difference -> { PersonalAccessToken.count }, 1 do
      post "/api/v1/cli/token", params: { code: raw }, as: :json
    end
    assert_response :success
    body = response.parsed_body
    assert body["token"].start_with?(PersonalAccessToken::PREFIX)
    assert_equal users(:translator).email, body.dig("user", "email")
  end

  test "401 for an invalid or reused code" do
    raw = CliAuthCode.issue(user: users(:translator), name: "laptop")
    post "/api/v1/cli/token", params: { code: raw }, as: :json
    assert_response :success

    post "/api/v1/cli/token", params: { code: raw }, as: :json # reused
    assert_response :unauthorized

    post "/api/v1/cli/token", params: { code: "bogus" }, as: :json
    assert_response :unauthorized
  end

  test "422 when the user is at their token limit" do
    Setting.current.update!(cli_token_limit: 1)
    PersonalAccessToken.issue(user: users(:translator), name: "existing")
    raw = CliAuthCode.issue(user: users(:translator), name: "laptop")

    post "/api/v1/cli/token", params: { code: raw }, as: :json
    assert_response :unprocessable_entity
  end
end
