require "test_helper"

class Projects::ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:main_app) }

  test "admin creates a token and sees the raw value once" do
    sign_in_as(users(:admin))
    assert_difference -> { @project.api_tokens.count }, 1 do
      post project_api_tokens_path(@project), params: { api_token: { name: "Web client", scope: "save_missing" } }
    end
    assert_redirected_to project_settings_path(@project)
    assert flash[:token_created].present?, "raw token should be flashed once"
    assert_equal "save_missing", @project.api_tokens.order(:created_at).last.scope
  end

  test "admin revokes a token" do
    sign_in_as(users(:admin))
    token = api_tokens(:save_missing)
    delete project_api_token_path(@project, token)
    assert_redirected_to project_settings_path(@project)
    assert_not_nil token.reload.revoked_at
  end

  test "non-admin cannot manage tokens" do
    sign_in_as(users(:translator))
    post project_api_tokens_path(@project), params: { api_token: { name: "x", scope: "save_missing" } }
    assert_response :forbidden
  end
end
