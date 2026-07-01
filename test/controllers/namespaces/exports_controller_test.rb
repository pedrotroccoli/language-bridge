require "test_helper"

class Namespaces::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
    sign_in_as(users(:translator))
  end

  # ---- data export (default: clean, metadata-free) ----

  test "data JSON for a single locale is nested and metadata-free" do
    get project_namespace_export_path(@project, @namespace, as: "json", locale: "en")
    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])

    data = JSON.parse(response.body)
    assert_equal "Hello", data["greeting"]
    assert_not data.key?("version")     # no snapshot metadata
    assert_not data.key?("farewell")    # empty value omitted
  end

  test "data JSON across multiple locales downloads a zip" do
    get project_namespace_export_path(@project, @namespace, as: "json")
    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match(/\.zip/, response.headers["Content-Disposition"])
  end

  test "data CSV for a single locale is a flat key,value file" do
    get project_namespace_export_path(@project, @namespace, as: "csv", locale: "en")
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "key,value", response.body
    assert_match "greeting,Hello", response.body
    assert_no_match(/published/, response.body)
  end

  # ---- backup export (opt-in: full-fidelity with metadata) ----

  test "backup JSON carries snapshot metadata" do
    get project_namespace_export_path(@project, @namespace, as: "json", mode: "backup")
    assert_response :success
    assert_equal "application/json", response.media_type
    data = JSON.parse(response.body)
    assert_equal TranslationSnapshot::VERSION, data["version"]
  end

  test "backup CSV keeps the metadata columns" do
    get project_namespace_export_path(@project, @namespace, as: "csv", mode: "backup")
    assert_response :success
    assert_match "namespace,key,locale,value,published", response.body
  end

  test "a viewer cannot export (drafts must not leak)" do
    sign_in_as(users(:viewer))
    get project_namespace_export_path(@project, @namespace, as: "json", locale: "en")
    assert_response :forbidden
  end
end
