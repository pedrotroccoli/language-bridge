require "test_helper"

class Api::V1::UserTest < ActionDispatch::IntegrationTest
  test "returns the token's user and accessible projects" do
    raw = PersonalAccessToken.issue(user: users(:admin), name: "laptop")
    get "/api/v1/user", headers: { "Authorization" => "Bearer #{raw}" }

    assert_response :success
    body = response.parsed_body
    assert_equal users(:admin).email, body.dig("user", "email")
    assert_kind_of Array, body["projects"]
  end

  test "401 without a valid personal access token" do
    get "/api/v1/user"
    assert_response :unauthorized

    get "/api/v1/user", headers: { "Authorization" => "Bearer nope" }
    assert_response :unauthorized
  end
end
