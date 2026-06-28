require "application_system_test_case"

class ProjectSettingsTest < ApplicationSystemTestCase
  test "admin renames project from the settings tab" do
    sign_in_as(users(:admin))
    visit settings_project_path(projects(:main_app))

    fill_in "Name", with: "Renamed Live"
    click_button "Save changes"

    assert_text "Project updated"
    assert_equal "Renamed Live", projects(:main_app).reload.name
  end
end
