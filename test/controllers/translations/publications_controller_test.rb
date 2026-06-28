require "test_helper"

class Translations::PublicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
    @translation = translations(:greeting_en)
  end

  test "redirects to sign_in when unauthenticated" do
    post project_translation_publication_path(@project, @translation)
    assert_redirected_to sign_in_path
  end

  test "viewer is forbidden" do
    sign_in_as(users(:viewer))
    post project_translation_publication_path(@project, @translation)
    assert_response :forbidden
  end

  test "translator publishes a translation" do
    sign_in_as(users(:translator))

    assert_difference "Translation::Publication.count", 1 do
      post project_translation_publication_path(@project, @translation)
    end
    assert @translation.reload.publication.present?
    assert_equal users(:translator), @translation.publication.publisher
    assert_redirected_to project_namespace_path(@project, @namespace)
  end

  test "publishing twice is idempotent" do
    sign_in_as(users(:translator))
    post project_translation_publication_path(@project, @translation)

    assert_no_difference "Translation::Publication.count" do
      post project_translation_publication_path(@project, @translation)
    end
  end

  test "publish via turbo frame streams the published cell with an Unpublish action" do
    sign_in_as(users(:translator))
    frame = "locale_#{@translation.locale_id}_translation_key_#{@translation.translation_key_id}"

    post project_translation_publication_path(@project, @translation), headers: { "Turbo-Frame" => frame }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target=?]", frame
    assert_select "turbo-stream[action=replace][target=publish_all]"
    assert @translation.reload.publication.present?
    assert_includes response.body, "Unpublish"
    assert_includes response.body, "Published"
  end

  test "translator unpublishes a translation" do
    sign_in_as(users(:translator))
    Translation::Publication.create!(translation: @translation)

    assert_difference "Translation::Publication.count", -1 do
      delete project_translation_publication_path(@project, @translation)
    end
    assert_nil @translation.reload.publication
  end
end
