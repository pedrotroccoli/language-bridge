require "test_helper"

class Projects::ActivityControllerTest < ActionDispatch::IntegrationTest
  test "show renders the activity feed for any member" do
    sign_in_as(users(:viewer))

    get project_activity_path(projects(:main_app))

    assert_response :success
  end

  test "show requires sign in" do
    get project_activity_path(projects(:main_app))

    assert_redirected_to sign_in_path
  end
end
