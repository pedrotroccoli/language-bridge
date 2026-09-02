require "test_helper"

class Projects::ReviewTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @common = namespaces(:main_app_common)
    @en = locales(:main_app_en)
    sign_in_as(users(:admin))
  end

  def draft(key:, value:, session:)
    record = @common.translation_keys.find_or_create_by!(key: key) { |k| k.project = @project }
    record.set_translation(locale: @en, value: value, author: users(:admin), session: session)
  end

  test "redirects into the editor filtered by the session's drafts" do
    draft(key: "zzwelcome", value: "Hi", session: "feat/x")

    get project_review_path(@project, session: "feat/x")
    assert_redirected_to project_namespace_path(@project, @common, session: "feat/x", status: "drafts")
  end

  test "falls back to the first namespace when the session has no drafts" do
    get project_review_path(@project, session: "empty")
    assert_response :redirect
    assert_match %r{/projects/#{@project.slug}/namespaces/}, response.location
  end
end
