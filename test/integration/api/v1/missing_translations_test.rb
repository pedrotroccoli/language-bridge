require "test_helper"

class Api::V1::MissingTranslationsTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @url = "/api/v1/projects/#{@project.slug}/missing"
    @auth = { "Authorization" => "Bearer test-save-missing-token" }
  end

  def post_missing(headers: @auth, **body)
    post @url, params: body, headers: headers, as: :json
  end

  test "records a report for an unknown key without creating real keys" do
    assert_difference -> { MissingKeyReport.count }, 1 do
      assert_no_difference [ "TranslationKey.count", "Translation.count" ] do
        post_missing(locale: "en", namespace: "common", keys: { "brand.new" => "Fresh" })
      end
    end
    assert_response :success
    assert_equal({ "status" => "ok", "reported" => 1 }, response.parsed_body)

    report = @project.missing_key_reports.find_by(namespace: "common", key: "brand.new")
    assert_equal 1, report.hits
    assert_equal [ "en" ], report.locales
  end

  test "a personal access token authenticates against an accessible project" do
    raw = PersonalAccessToken.regenerate_for(users(:admin))

    assert_difference -> { MissingKeyReport.count }, 1 do
      post_missing(headers: { "Authorization" => "Bearer #{raw}" },
                   locale: "en", namespace: "common", keys: { "pat.key" => "x" })
    end
    assert_response :success
  end

  test "replaying the same payload bumps hits, not rows" do
    post_missing(locale: "en", namespace: "common", keys: { "brand.new" => "Fresh" })
    assert_no_difference -> { MissingKeyReport.count } do
      post_missing(locale: "en", namespace: "common", keys: { "brand.new" => "Fresh" })
    end
    assert_equal 2, @project.missing_key_reports.find_by(key: "brand.new").hits
  end

  test "accumulates the locales that report a key" do
    post_missing(locale: "en", namespace: "common", keys: { "brand.new" => "x" })
    post_missing(locale: "pt-BR", namespace: "common", keys: { "brand.new" => "x" })
    assert_equal %w[ en pt-BR ], @project.missing_key_reports.find_by(key: "brand.new").locales
  end

  test "returns the count of reported keys" do
    post_missing(locale: "en", namespace: "common", keys: { "a.one" => "1", "a.two" => "2" })
    assert_response :success
    assert_equal 2, response.parsed_body["reported"]
  end

  test "422 when keys are absent or empty" do
    post_missing(locale: "en", namespace: "common")
    assert_response :unprocessable_entity
    post_missing(locale: "en", namespace: "common", keys: {})
    assert_response :unprocessable_entity
  end

  test "422 when locale or namespace is missing" do
    post_missing(namespace: "common", keys: { "a.one" => "1" })
    assert_response :unprocessable_entity
    post_missing(locale: "en", keys: { "a.one" => "1" })
    assert_response :unprocessable_entity
  end

  test "404 when the project slug is unknown" do
    post "/api/v1/projects/does-not-exist/missing",
         params: { locale: "en", namespace: "common", keys: { "a.one" => "1" } },
         headers: @auth, as: :json
    assert_response :not_found
  end

  test "401 when the bearer token is missing or invalid" do
    post_missing(headers: {}, locale: "en", namespace: "common", keys: { "a.one" => "1" })
    assert_response :unauthorized
    post_missing(headers: { "Authorization" => "Bearer wrong-token" }, locale: "en", namespace: "common", keys: { "a.one" => "1" })
    assert_response :unauthorized
  end

  test "403 when the token lacks the save_missing scope" do
    post_missing(headers: { "Authorization" => "Bearer test-read-only-token" }, locale: "en", namespace: "common", keys: { "a.one" => "1" })
    assert_response :forbidden
  end

  test "422 when the payload exceeds the per-request key cap" do
    keys = (1..501).to_h { |i| [ "k.#{i}", "v" ] }
    assert_no_difference -> { MissingKeyReport.count } do
      post_missing(locale: "en", namespace: "common", keys: keys)
    end
    assert_response :unprocessable_entity
  end

  test "422 when a namespace is absurdly long" do
    post_missing(locale: "en", namespace: "n" * 300, keys: { "a.b" => "x" })
    assert_response :unprocessable_entity
  end
end
