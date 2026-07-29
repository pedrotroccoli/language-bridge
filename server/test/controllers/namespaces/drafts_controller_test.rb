require "test_helper"

class Namespaces::DraftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
  end

  test "admin discards all drafts in the namespace" do
    sign_in_as(users(:admin))
    key = @namespace.translation_keys.create!(project: @project, key: "draft.k")
    Translation.create!(translation_key: key, locale: locales(:main_app_en), value: "draft") # unpublished → draft
    assert_operator Translation.drafts_in_namespace(@namespace).count, :>, 0

    delete project_namespace_drafts_path(@project, @namespace)

    assert_equal 0, Translation.drafts_in_namespace(@namespace).count
    assert_redirected_to project_namespace_path(@project, @namespace)
  end

  test "non-editor cannot discard" do
    sign_in_as(users(:viewer))
    delete project_namespace_drafts_path(@project, @namespace)
    assert_response :forbidden
  end
end
