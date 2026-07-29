require "test_helper"

class Projects::UploadSettingsControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:main_app) }

  test "blank storage connection coerces to nil (workspace default)" do
    sign_in_as(users(:admin))
    @project.update!(storage_connection: StorageConnection.create!(name: "B", service: "local"))

    patch project_upload_settings_path(@project), params: { project: { storage_connection_id: "" } }

    assert_redirected_to project_settings_path(@project)
    assert_nil @project.reload.storage_connection_id
  end

  test "saves override formats and path" do
    sign_in_as(users(:admin))
    patch project_upload_settings_path(@project), params: { project: {
      upload_override: "1", upload_path: "uploads", upload_allowed_formats: %w[ json csv ]
    } }

    @project.reload
    assert @project.upload_override
    assert_equal "uploads", @project.upload_path
    assert_equal %w[ json csv ], @project.upload_allowed_formats
  end

  test "non-admin is blocked" do
    sign_in_as(users(:translator))
    patch project_upload_settings_path(@project), params: { project: { upload_path: "x" } }
    assert_response :forbidden
  end
end
