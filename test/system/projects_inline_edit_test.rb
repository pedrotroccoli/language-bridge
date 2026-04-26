require "application_system_test_case"

class ProjectsInlineEditTest < ApplicationSystemTestCase
  test "admin double-clicks title to edit and saves" do
    sign_in_as(users(:admin))
    visit project_path(projects(:main_app))

    find(".title-row h1").double_click

    input = find('input[data-inline-edit-target="input"]', visible: true)
    input.fill_in with: "Renamed Live"
    click_button "Save"

    assert_text "Renamed Live"
    assert_selector ".title-row h1", text: "Renamed Live"
  end

  test "Escape cancels inline edit" do
    sign_in_as(users(:admin))
    visit project_path(projects(:main_app))

    find(".title-row h1").double_click

    input = find('input[data-inline-edit-target="input"]', visible: true)
    input.send_keys :escape

    assert_no_selector 'input[data-inline-edit-target="input"]', visible: true
    assert_selector ".title-row h1"
  end
end
