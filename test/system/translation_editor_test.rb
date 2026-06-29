require "application_system_test_case"

class TranslationEditorTest < ApplicationSystemTestCase
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
    @en = locales(:main_app_en)
    @greeting = translation_keys(:main_app_common_greeting)
  end

  def cell_frame(key, locale)
    "locale_#{locale.id}_translation_key_#{key.id}"
  end

  test "translator edits a value and publishes it" do
    sign_in_as(users(:translator))
    visit project_namespace_path(@project, @namespace)

    within "##{cell_frame(@greeting, @en)}" do
      input = find("textarea")
      input.fill_in with: "Hi there"
      input.send_keys :tab
      assert_button "Publish"
      click_button "Publish"
      assert_text "Unpublish"
    end

    translation = Translation.find_by!(translation_key: @greeting, locale: @en)
    assert_equal "Hi there", translation.value
    assert translation.publication.present?
  end

  test "admin adds a locale via modal" do
    sign_in_as(users(:admin))
    visit project_path(@project)

    within ".locales-section" do
      click_button "New locale"
      # Multi-select combobox: type a custom IETF tag and press Enter to add it.
      find('input[data-combobox-target="input"]').send_keys("fr", :enter)
      click_button "Add languages"
    end

    assert_text "Added 1 locale"
    assert @project.locales.exists?(code: "fr")
  end
end
