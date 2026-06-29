require "test_helper"

class Namespaces::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
  end

  test "downloads the namespace as JSON" do
    sign_in_as(users(:translator))
    get project_namespace_export_path(@project, @namespace, as: "json")
    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
  end

  test "downloads the namespace as CSV" do
    sign_in_as(users(:translator))
    get project_namespace_export_path(@project, @namespace, as: "csv")
    assert_response :success
    assert_match "namespace,key,locale,value,published", response.body
  end
end
