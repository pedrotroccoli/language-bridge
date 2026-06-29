require "test_helper"

class TranslationSnapshotTest < ActiveSupport::TestCase
  test "build serializes namespaces, keys, locales, values and published state" do
    source = projects(:main_app)
    translations(:greeting_en).publish

    data = JSON.parse(TranslationSnapshot.build(source).to_json)

    assert_equal 1, data["version"]
    assert_includes data["locales"], "en"
    entry = data.dig("namespaces", "common", "greeting", "en")
    assert_equal "Hello", entry["value"]
    assert_equal true, entry["published"]
  end

  test "restore reproduces the translation set in a fresh project" do
    source = projects(:main_app)
    translations(:greeting_en).publish
    data = JSON.parse(TranslationSnapshot.build(source).to_json)

    target = Project.create!(name: "Restore Target")
    count = TranslationSnapshot.restore(target, data)

    assert count.positive?
    namespace = target.namespaces.find_by(name: "common")
    key = target.translation_keys.find_by(namespace: namespace, key: "greeting")
    translation = key.translations.find_by(locale: target.locales.find_by(code: "en"))
    assert_equal "Hello", translation.value
    assert translation.published?, "published state should be restored"
  end
end
