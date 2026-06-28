require "test_helper"

class TranslationKeyTest < ActiveSupport::TestCase
  test "valid with project, namespace and key" do
    key = TranslationKey.new(project: projects(:main_app), namespace: namespaces(:main_app_common), key: "welcome")
    assert key.valid?
  end

  test "requires project" do
    key = TranslationKey.new(namespace: namespaces(:main_app_common), key: "welcome")
    assert_not key.valid?
    assert_includes key.errors[:project], "must exist"
  end

  test "requires namespace" do
    key = TranslationKey.new(project: projects(:main_app), key: "welcome")
    assert_not key.valid?
    assert_includes key.errors[:namespace], "must exist"
  end

  test "requires key" do
    key = TranslationKey.new(project: projects(:main_app), namespace: namespaces(:main_app_common))
    assert_not key.valid?
    assert_includes key.errors[:key], "can't be blank"
  end

  test "key unique per project and namespace" do
    existing = translation_keys(:main_app_common_greeting)
    duplicate = TranslationKey.new(project: existing.project, namespace: existing.namespace, key: existing.key)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "same key allowed in different namespace" do
    existing = translation_keys(:main_app_common_greeting)
    key = TranslationKey.new(project: existing.project, namespace: namespaces(:main_app_marketing), key: existing.key)
    assert key.valid?
  end

  test "counter cache increments project and namespace on create" do
    project = Project.create!(name: "Counter Test")
    namespace = project.namespaces.create!(name: "auth")
    assert_difference [ -> { project.reload.translation_keys_count }, -> { namespace.reload.translation_keys_count } ], 1 do
      namespace.translation_keys.create!(project: project, key: "login")
    end
  end

  test "counter cache decrements on destroy" do
    project = Project.create!(name: "Counter Decrement")
    namespace = project.namespaces.create!(name: "auth")
    key = namespace.translation_keys.create!(project: project, key: "login")
    assert_difference [ -> { project.reload.translation_keys_count }, -> { namespace.reload.translation_keys_count } ], -1 do
      key.destroy!
    end
  end

  test "with_translations scope filters by locale" do
    key = translation_keys(:main_app_common_greeting)
    result = TranslationKey.with_translations(locales(:main_app_en)).where(id: key.id).first
    assert_equal [ translations(:greeting_en) ], result.translations.to_a
  end

  test "destroys dependent translations" do
    key = translation_keys(:main_app_common_greeting)
    assert_difference -> { Translation.count }, -key.translations.count do
      key.destroy!
    end
  end
end
