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

  test "admin creates key with context and a source-locale draft value" do
    sign_in_as(users(:admin))
    source = @project.locales.alphabetically.first

    assert_difference "TranslationKey.count", 1 do
      post project_namespace_translation_keys_path(@project, @namespace),
           params: { translation_key: { key: "ctx.key", context: "shown to translators", source_value: "Hello there" } }
    end

    key = @namespace.translation_keys.find_by(key: "ctx.key")
    assert_equal "shown to translators", key.context
    translation = key.translations.find_by(locale: source)
    assert_equal "Hello there", translation.value
    assert translation.draft?, "source value should be created as a draft"
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

  test "destroying a published key rebuilds its artifact without the key" do
    sign_in_as(users(:admin))
    greeting = translations(:greeting_en) # key "greeting", value "Hello"
    greeting.publish(by: users(:admin))
    assert_equal({ "greeting" => "Hello" }, JSON.parse(DeliveryCompression.decompress(artifact.file.download, artifact.content_encoding)))

    delete project_namespace_translation_key_path(@project, @namespace, greeting.translation_key)

    assert_equal({}, JSON.parse(DeliveryCompression.decompress(artifact.file.download, artifact.content_encoding)))
  end

  test "detail drawer shows per-locale state and version history" do
    sign_in_as(users(:viewer))
    key = translation_keys(:main_app_common_greeting)
    translations(:greeting_en).update!(value: "Hi there", author: users(:translator)) # creates a Version

    get project_namespace_translation_key_path(@project, @namespace, key)

    assert_response :success
    assert_select "turbo-frame#key_detail"
    assert_select "body", /History/
    assert_select "body", /Hello/ # the snapshotted previous value
  end

  test "saving context from the drawer reloads the frame" do
    sign_in_as(users(:admin))
    key = translation_keys(:main_app_common_greeting)

    patch project_namespace_translation_key_path(@project, @namespace, key),
          params: { translation_key: { context: "Shown on the home screen" } },
          headers: { "Turbo-Frame" => "key_detail" }

    assert_redirected_to project_namespace_translation_key_path(@project, @namespace, key)
    assert_equal "Shown on the home screen", key.reload.context
  end

  private
    def artifact
      Translation::Artifact.find_by!(namespace: @namespace, locale: locales(:main_app_en))
    end
end
