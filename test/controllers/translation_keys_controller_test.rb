require "test_helper"

class TranslationKeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
  end

  test "redirects to sign_in when unauthenticated" do
    post project_namespace_translation_keys_path(@project, @namespace), params: { translation_key: { key: "x" } }
    assert_redirected_to sign_in_path
  end

  test "non-admin cannot create/update/destroy" do
    sign_in_as(users(:translator))

    assert_no_difference "TranslationKey.count" do
      post project_namespace_translation_keys_path(@project, @namespace), params: { translation_key: { key: "sneaky" } }
    end
    assert_response :forbidden

    key = translation_keys(:main_app_common_greeting)
    patch project_namespace_translation_key_path(@project, @namespace, key), params: { translation_key: { key: "x" } }
    assert_response :forbidden

    delete project_namespace_translation_key_path(@project, @namespace, key)
    assert_response :forbidden
  end

  test "admin creates key" do
    sign_in_as(users(:admin))

    assert_difference "@namespace.translation_keys.count", 1 do
      post project_namespace_translation_keys_path(@project, @namespace), params: { translation_key: { key: "welcome" } }
    end
    assert_redirected_to project_namespace_path(@project, @namespace)
    assert_match(/Key created/, flash[:notice])
    assert @namespace.translation_keys.exists?(key: "welcome")
  end

  test "admin sees alert on duplicate key" do
    sign_in_as(users(:admin))

    assert_no_difference "TranslationKey.count" do
      post project_namespace_translation_keys_path(@project, @namespace),
           params: { translation_key: { key: translation_keys(:main_app_common_greeting).key } }
    end
    assert flash[:alert].present?
    assert_equal translation_keys(:main_app_common_greeting).key, flash[:invalid_translation_key]
  end

  test "admin destroys key" do
    sign_in_as(users(:admin))
    key = @namespace.translation_keys.create!(project: @project, key: "disposable")

    assert_difference "@namespace.translation_keys.count", -1 do
      delete project_namespace_translation_key_path(@project, @namespace, key)
    end
    assert_redirected_to project_namespace_path(@project, @namespace)
  end

  private
    def sign_in_as(user)
      token = user.sign_in_tokens.create!
      get sign_in_with_token_path(token: token.token)
    end
end
