require "test_helper"

class Api::V1::ExportsTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @url = "/api/v1/projects/#{@project.slug}/export"
    # Any valid token reads — use the read-only one to prove no scope is required.
    @auth = { "Authorization" => "Bearer test-read-only-token" }
    translations(:greeting_en).publish(by: users(:admin))
  end

  def get_export(headers: @auth, **params)
    get @url, params: params, headers: headers
  end

  test "returns published translations for one locale as nested namespaces" do
    get_export(locale: "en")
    assert_response :success
    body = response.parsed_body
    assert_equal "main-app", body["project"]
    assert_equal "en", body["locale"]
    assert_equal({ "common" => { "greeting" => "Hello" } }, body["namespaces"])
  end

  test "reports available and source locales" do
    locales(:main_app_en).mark_as_source!
    get_export(locale: "en")
    assert_response :success
    body = response.parsed_body
    assert_equal %w[ en pt-BR ], body["available_locales"]
    assert_equal "en", body["source_locale"]
    assert_equal true, body["is_source"]
  end

  test "defaults to the source locale when none is given" do
    locales(:main_app_en).mark_as_source!
    get_export
    assert_response :success
    assert_equal "en", response.parsed_body["locale"]
  end

  test "excludes unpublished values by default" do
    get_export(locale: "pt-BR") # greeting_pt is a draft
    assert_response :success
    assert_equal({}, response.parsed_body["namespaces"])
  end

  test "include_drafts returns unpublished values for an editor-scoped token" do
    get_export(headers: { "Authorization" => "Bearer test-save-missing-token" },
               locale: "pt-BR", include_drafts: "1")
    assert_response :success
    assert_equal({ "common" => { "greeting" => "Olá" } }, response.parsed_body["namespaces"])
  end

  test "include_drafts is forbidden for a read-only token" do
    get_export(locale: "pt-BR", include_drafts: "1") # @auth is the read-only token
    assert_response :forbidden
  end

  test "a viewer's PAT cannot read drafts" do
    raw = PersonalAccessToken.regenerate_for(users(:viewer))
    get_export(headers: { "Authorization" => "Bearer #{raw}" }, locale: "en", include_drafts: "1")
    assert_response :forbidden
  end

  test "a personal access token authenticates against an accessible project" do
    raw = PersonalAccessToken.regenerate_for(users(:viewer)) # even a viewer may read
    get_export(headers: { "Authorization" => "Bearer #{raw}" }, locale: "en")
    assert_response :success
  end

  test "404 when the locale is unknown" do
    get_export(locale: "zz")
    assert_response :not_found
  end

  test "404 when the project slug is unknown" do
    get "/api/v1/projects/does-not-exist/export", params: { locale: "en" }, headers: @auth
    assert_response :not_found
  end

  test "401 when the bearer token is missing or invalid" do
    get_export(headers: {}, locale: "en")
    assert_response :unauthorized
    get_export(headers: { "Authorization" => "Bearer wrong-token" }, locale: "en")
    assert_response :unauthorized
  end
end
