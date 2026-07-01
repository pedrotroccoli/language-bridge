require "test_helper"

class DeliveryTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @locale = locales(:main_app_en)
    @namespace = namespaces(:main_app_common)
    translations(:greeting_en).publish(by: users(:admin)) # materializes the artifact
  end

  test "serves published translations as nested JSON without authentication" do
    get cdn_path("common")
    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal({ "greeting" => "Hello" }, response.parsed_body)
  end

  test "accepts the optional .json suffix" do
    get cdn_path("common.json")
    assert_response :success
    assert_equal({ "greeting" => "Hello" }, response.parsed_body)
  end

  test "excludes unpublished translations" do
    translations(:greeting_en).unpublish # rebuilds the artifact without it
    get cdn_path("common")
    assert_response :success
    assert_equal({}, response.parsed_body)
  end

  test "serves the materialized artifact when present" do
    assert Translation::Artifact.exists?(namespace: @namespace, locale: @locale)
    get cdn_path("common")
    assert_response :success
    assert_equal({ "greeting" => "Hello" }, response.parsed_body)
  end

  test "sets a CDN-friendly cache-control and an ETag" do
    get cdn_path("common")
    assert_response :success
    cache_control = response.headers["Cache-Control"]
    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=3600"
    assert_includes cache_control, "stale-while-revalidate=300"
    assert response.headers["ETag"].present?
  end

  test "returns 304 with cache headers when the ETag matches" do
    get cdn_path("common")
    etag = response.headers["ETag"]
    get cdn_path("common"), headers: { "If-None-Match" => etag }
    assert_response :not_modified
    assert_includes response.headers["Cache-Control"], "max-age=3600"
  end

  test "matches a namespace whose name literally ends in .json" do
    dotted = @project.namespaces.create!(name: "config.json")
    key = dotted.translation_keys.create!(project: @project, key: "title")
    Translation.create!(translation_key: key, locale: @locale, value: "Hi").publish(by: users(:admin))

    get cdn_path("config.json")
    assert_response :success
    assert_equal({ "title" => "Hi" }, response.parsed_body)
  end

  test "serves the stored gzip bytes under Content-Encoding when the client accepts gzip" do
    get cdn_path("common"), headers: { "Accept-Encoding" => "gzip" }
    assert_response :success
    assert_equal "gzip", response.headers["Content-Encoding"]
    assert_includes response.headers["Vary"].to_s, "Accept-Encoding"
    assert_equal({ "greeting" => "Hello" }, JSON.parse(ActiveSupport::Gzip.decompress(response.body)))
  end

  test "decompresses to plain JSON for a client that does not accept gzip" do
    get cdn_path("common"), headers: { "Accept-Encoding" => "identity" }
    assert_response :success
    assert_nil response.headers["Content-Encoding"]
    assert_equal({ "greeting" => "Hello" }, response.parsed_body)
  end

  test "serves plain JSON when the client explicitly refuses gzip via q=0" do
    get cdn_path("common"), headers: { "Accept-Encoding" => "gzip;q=0" }
    assert_response :success
    assert_nil response.headers["Content-Encoding"]
    assert_equal({ "greeting" => "Hello" }, response.parsed_body)
  end

  test "ETag is stable across compression so 304 still works for a gzip client" do
    get cdn_path("common"), headers: { "Accept-Encoding" => "gzip" }
    etag = response.headers["ETag"]
    assert etag.present?

    get cdn_path("common"), headers: { "Accept-Encoding" => "gzip", "If-None-Match" => etag }
    assert_response :not_modified
  end

  test "404 for an unknown project" do
    get "/cdn/nope/en/common"
    assert_response :not_found
  end

  test "404 for an unknown locale" do
    get "/cdn/#{@project.slug}/zz/common"
    assert_response :not_found
  end

  test "404 for an unknown namespace" do
    get cdn_path("ghost")
    assert_response :not_found
  end

  private
    def cdn_path(namespace)
      "/cdn/#{@project.slug}/#{@locale.code}/#{namespace}"
    end
end
