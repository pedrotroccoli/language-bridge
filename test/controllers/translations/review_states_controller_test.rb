require "test_helper"

class Translations::ReviewStatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
    @translation = translations(:greeting_en)
  end

  test "viewer cannot mark for review or approve" do
    sign_in_as(users(:viewer))
    post project_translation_review_path(@project, @translation)
    assert_response :forbidden
    post project_translation_approval_path(@project, @translation)
    assert_response :forbidden
  end

  test "translator marks a translation for review" do
    sign_in_as(users(:translator))
    assert_difference "Translation::Review.count", 1 do
      post project_translation_review_path(@project, @translation)
    end
    assert @translation.reload.under_review?
    assert_redirected_to project_namespace_path(@project, @namespace)
  end

  test "translator approves, clearing the review" do
    sign_in_as(users(:translator))
    @translation.request_review(by: users(:translator))

    assert_difference "Translation::Approval.count", 1 do
      post project_translation_approval_path(@project, @translation)
    end
    assert @translation.reload.approved?
    assert_not @translation.under_review?
  end

  test "review filter lists only under-review keys" do
    sign_in_as(users(:translator))
    @translation.request_review(by: users(:translator))

    get project_namespace_path(@project, @namespace, status: "review")
    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(@translation.translation_key)}"
  end
end
