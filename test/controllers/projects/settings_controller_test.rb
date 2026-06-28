require "test_helper"

class Projects::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "admin sees the settings page" do
    sign_in_as(users(:admin))

    get project_settings_path(projects(:main_app))

    assert_response :success
  end

  test "non-admin is forbidden" do
    sign_in_as(users(:translator))

    get project_settings_path(projects(:main_app))

    assert_response :forbidden
  end
end
