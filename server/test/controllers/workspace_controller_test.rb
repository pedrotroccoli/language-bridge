require "test_helper"

class WorkspaceControllerTest < ActionDispatch::IntegrationTest
  test "admin sees the workspace settings page" do
    sign_in_as(users(:admin))
    get workspace_path
    assert_response :success
    assert_select "h2", "Workspace settings"
  end

  test "admin updates global rate-limit settings" do
    sign_in_as(users(:admin))
    patch workspace_path, params: { setting: {
      rate_limiting_enabled: "1", missing_rate_limit: 45, missing_rate_period: 30,
      delivery_rate_limit: 500, delivery_rate_period: 60
    } }
    assert_redirected_to workspace_path
    assert_equal 45, Setting.current.missing_rate_limit
    assert_equal 500, Setting.current.delivery_rate_limit
  end

  test "non-admin is redirected away" do
    sign_in_as(users(:translator))
    get workspace_path
    assert_redirected_to root_path
  end
end
