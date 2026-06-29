require "test_helper"

class ProjectsRateLimitOverrideTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:main_app) }

  test "admin sets a per-project rate-limit override" do
    sign_in_as(users(:admin))
    patch project_path(@project), params: { project: { missing_rate_limit: 50, delivery_rate_limit: 400 } }
    assert_redirected_to project_path(@project)
    @project.reload
    assert_equal 50, @project.missing_rate_limit
    assert_equal 50, @project.effective_missing_limit
    assert_equal 400, @project.effective_delivery_limit
  end

  test "blank override falls back to the global default" do
    @project.update!(missing_rate_limit: 50)
    assert_equal 50, @project.effective_missing_limit
    @project.update!(missing_rate_limit: nil)
    assert_equal Setting.current.missing_rate_limit, @project.effective_missing_limit
  end
end
