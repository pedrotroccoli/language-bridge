require "test_helper"

# CORS is configured in config/initializers/cors.rb. The public delivery
# endpoint (/cdn/*) is always open to any origin; the private API (/api/*) is
# restricted to the origins stored in Setting#allowed_origins (managed from the
# Workspace settings panel), evaluated per request.
class CorsTest < ActionDispatch::IntegrationTest
  test "delivery endpoint allows any origin and exposes ETag" do
    get "/cdn/anything/en/common", headers: { "Origin" => "https://random-site.io" }

    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Expose-Headers"], "ETag"
  end

  test "delivery preflight permits only read methods" do
    process :options, "/cdn/anything/en/common", headers: {
      "Origin" => "https://random-site.io",
      "Access-Control-Request-Method" => "GET"
    }

    assert_response :success
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    methods = response.headers["Access-Control-Allow-Methods"]
    assert_includes methods, "GET"
    assert_not_includes methods, "POST"
  end

  test "private API rejects cross-origin requests when no origins configured" do
    Setting.current.update!(allowed_origins: [])

    process :options, "/api/v1/projects/foo/missing", headers: {
      "Origin" => "https://app.example.com",
      "Access-Control-Request-Method" => "POST"
    }

    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "private API allows a configured origin and rejects others" do
    Setting.current.update!(allowed_origins: %w[ https://app.example.com ])

    process :options, "/api/v1/projects/foo/missing", headers: {
      "Origin" => "https://app.example.com",
      "Access-Control-Request-Method" => "POST"
    }
    assert_equal "https://app.example.com", response.headers["Access-Control-Allow-Origin"]

    process :options, "/api/v1/projects/foo/missing", headers: {
      "Origin" => "https://evil.io",
      "Access-Control-Request-Method" => "POST"
    }
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end
end
