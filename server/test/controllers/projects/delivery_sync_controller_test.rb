require "test_helper"

class Projects::DeliverySyncControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:main_app) }

  test "admin syncs all published pairs to storage" do
    translations(:greeting_en).publish(by: users(:admin))

    sign_in_as(users(:admin))
    post project_delivery_sync_path(@project)

    assert_redirected_to project_settings_path(@project)
    assert_match(/synced/i, flash[:notice])
  end

  test "non-admin cannot sync" do
    sign_in_as(users(:translator))
    post project_delivery_sync_path(@project)
    assert_response :forbidden
  end
end
