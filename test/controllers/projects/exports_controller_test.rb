require "test_helper"

class Projects::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    sign_in_as(users(:translator))
  end

  test "data export bundles the whole project as a zip" do
    get project_export_path(@project, as: "json")
    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_match(/main-app-json\.zip/, response.headers["Content-Disposition"])
  end

  test "backup export dumps the full project snapshot with metadata" do
    get project_export_path(@project, as: "json", mode: "backup")
    assert_response :success
    assert_equal "application/json", response.media_type
    data = JSON.parse(response.body)
    assert_equal TranslationSnapshot::VERSION, data["version"]
    assert data["namespaces"].key?("common")
  end

  test "a viewer cannot export (drafts must not leak)" do
    sign_in_as(users(:viewer))
    get project_export_path(@project, as: "json")
    assert_response :forbidden
  end
end
