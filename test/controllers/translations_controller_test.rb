require "test_helper"

class TranslationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
  end

  test "redirects to sign_in when unauthenticated" do
    patch project_translation_path(@project, translations(:greeting_en)), params: { translation: { value: "x" } }
    assert_redirected_to sign_in_path
  end

  test "viewer is forbidden" do
    sign_in_as(users(:viewer))
    patch project_translation_path(@project, translations(:greeting_en)), params: { translation: { value: "x" } }
    assert_response :forbidden
  end

  test "translator creates a translation for an empty cell" do
    sign_in_as(users(:translator))
    key = translation_keys(:main_app_common_farewell)
    locale = locales(:main_app_pt_br)

    assert_difference "Translation.count", 1 do
      post project_translations_path(@project),
           params: { translation: { translation_key_id: key.id, locale_id: locale.id, value: "Adeus" } }
    end
    translation = Translation.find_by!(translation_key: key, locale: locale)
    assert_equal "Adeus", translation.value
    assert_equal users(:translator), translation.author
    assert_redirected_to project_namespace_path(@project, @namespace)
  end

  test "translator updates a value and snapshots a version" do
    sign_in_as(users(:translator))
    translation = translations(:greeting_en)

    assert_difference "translation.versions.count", 1 do
      patch project_translation_path(@project, translation), params: { translation: { value: "Hi there" } }
    end
    assert_equal "Hi there", translation.reload.value
    assert_equal users(:translator), translation.author
    assert_equal "Hello", translation.versions.order(:created_at).last.value
    assert_redirected_to project_namespace_path(@project, @namespace)
  end

  test "update via turbo frame returns a stream replacing the cell and publish-all" do
    sign_in_as(users(:translator))
    translation = translations(:greeting_en)
    frame = "locale_#{translation.locale_id}_translation_key_#{translation.translation_key_id}"

    patch project_translation_path(@project, translation),
          params: { translation: { value: "Hi" } },
          headers: { "Turbo-Frame" => frame }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target=?]", frame
    assert_select "turbo-stream[action=replace][target=publish_all]"
    assert_equal "Hi", translation.reload.value
  end

  test "editing a published translation via turbo frame returns it to draft" do
    sign_in_as(users(:translator))
    translation = translations(:greeting_en)
    Translation::Publication.create!(translation: translation)
    frame = "locale_#{translation.locale_id}_translation_key_#{translation.translation_key_id}"

    patch project_translation_path(@project, translation),
          params: { translation: { value: "Reworded" } },
          headers: { "Turbo-Frame" => frame }

    assert_response :success
    assert_nil translation.reload.publication
    assert_includes response.body, "Draft"
  end

  test "admin can update too" do
    sign_in_as(users(:admin))
    translation = translations(:greeting_pt)
    patch project_translation_path(@project, translation), params: { translation: { value: "Oi" } }
    assert_equal "Oi", translation.reload.value
  end

  private
    def sign_in_as(user)
      token = user.sign_in_tokens.create!
      get sign_in_with_token_path(token: token.token)
    end
end
