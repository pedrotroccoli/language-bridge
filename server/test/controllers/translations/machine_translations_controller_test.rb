require "test_helper"

class Translations::MachineTranslationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
    @source = locales(:main_app_en)
    @source.mark_as_source!
    @target = locales(:main_app_pt_br)
    @key = translation_keys(:main_app_common_greeting) # has greeting_en = "Hello"
  end

  test "viewer is forbidden" do
    sign_in_as(users(:viewer))
    post project_machine_translation_path(@project),
         params: { translation_key_id: @key.id, locale_id: @target.id }
    assert_response :forbidden
  end

  test "translator auto-translates a missing cell into a draft" do
    sign_in_as(users(:translator))

    post project_machine_translation_path(@project),
         params: { translation_key_id: @key.id, locale_id: @target.id }

    draft = @key.translations.find_by(locale: @target)
    assert_equal "[pt-BR] Hello", draft.value
    assert draft.draft?
    assert_redirected_to project_namespace_path(@project, @namespace)
  end

  test "unprocessable when translating the source locale itself" do
    sign_in_as(users(:translator))
    post project_machine_translation_path(@project),
         params: { translation_key_id: @key.id, locale_id: @source.id }
    assert_response :unprocessable_entity
  end
end
