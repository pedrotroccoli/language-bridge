require "test_helper"

class TranslationBundleTest < ActiveSupport::TestCase
  setup do
    @namespace = namespaces(:main_app_common)
    @locale = locales(:main_app_en)
  end

  test "includes only published translations with a value" do
    publish translations(:greeting_en) # "Hello"
    # farewell_en_missing has no value; greeting_pt is another locale
    assert_equal({ "greeting" => "Hello" }, bundle.to_h)
  end

  test "excludes unpublished translations" do
    # greeting_en has a value but no publication
    assert_equal({}, bundle.to_h)
  end

  test "expands dotted keys into nested objects" do
    key = @namespace.translation_keys.create!(project: @namespace.project, key: "home.title")
    publish Translation.create!(translation_key: key, locale: @locale, value: "Welcome")
    assert_equal({ "home" => { "title" => "Welcome" } }, bundle.to_h)
  end

  test "etag changes when content changes" do
    publish translations(:greeting_en)
    before = bundle.etag
    translations(:greeting_en).update!(value: "Hi") # editing unpublishes
    assert_not_equal before, bundle.etag
  end

  test "etag is stable for identical content" do
    publish translations(:greeting_en)
    assert_equal bundle.etag, bundle.etag
  end

  test "include_drafts unions published rows with every draft" do
    publish translations(:greeting_en)
    key = @namespace.translation_keys.create!(project: @namespace.project, key: "cta")
    Translation.create!(translation_key: key, locale: @locale, value: "Try it", session: "feat/x")

    playground = TranslationBundle.new(namespace: @namespace, locale: @locale, include_drafts: true)
    assert_equal({ "greeting" => "Hello", "cta" => "Try it" }, playground.to_h)
  end

  test "a session bundle unions published rows with that session's drafts" do
    publish translations(:greeting_en) # published, no session
    key = @namespace.translation_keys.create!(project: @namespace.project, key: "cta")
    Translation.create!(translation_key: key, locale: @locale, value: "Try it", session: "feat/x")
    other = @namespace.translation_keys.create!(project: @namespace.project, key: "other")
    Translation.create!(translation_key: other, locale: @locale, value: "Nope", session: "feat/y")

    session_bundle = TranslationBundle.new(namespace: @namespace, locale: @locale, session: "feat/x")
    assert_equal({ "greeting" => "Hello", "cta" => "Try it" }, session_bundle.to_h)
  end

  private
    def bundle
      TranslationBundle.new(namespace: @namespace, locale: @locale)
    end

    def publish(translation)
      Translation::Publication.create!(translation: translation, publisher: users(:admin))
      translation
    end
end
