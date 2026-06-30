require "test_helper"

class MachineTranslationJobTest < ActiveJob::TestCase
  setup do
    @project = projects(:main_app)
    @source = locales(:main_app_en)
    @source.mark_as_source!
    @target = locales(:main_app_pt_br)
  end

  test "fills empty target keys with machine-translated drafts" do
    key = @project.translation_keys.create!(namespace: namespaces(:main_app_common), key: "mt.greeting")
    key.set_translation(locale: @source, value: "Hello", author: users(:admin))

    MachineTranslationJob.perform_now(@target)

    draft = key.translations.find_by(locale: @target)
    assert_equal "[pt-BR] Hello", draft.value
    assert draft.draft?, "machine translation should be an unpublished draft"
  end

  test "does not overwrite an existing target value" do
    key = @project.translation_keys.create!(namespace: namespaces(:main_app_common), key: "mt.keep")
    key.set_translation(locale: @source, value: "Hello", author: users(:admin))
    key.set_translation(locale: @target, value: "Olá já existe", author: users(:admin))

    MachineTranslationJob.perform_now(@target)

    assert_equal "Olá já existe", key.translations.find_by(locale: @target).value
  end
end
