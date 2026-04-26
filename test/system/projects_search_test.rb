require "application_system_test_case"

class ProjectsSearchTest < ApplicationSystemTestCase
  test "filters cards by name" do
    sign_in_as(users(:admin))
    visit projects_path

    assert_selector "article.project-card", count: 2
    assert_text "Main App"
    assert_text "Marketing Site"

    find('input[data-search-target="input"]').fill_in with: "main"

    assert_selector "article.project-card:not([hidden])", count: 1
    assert_text "Main App"
    assert_no_selector "article.project-card:not([hidden])", text: "Marketing Site"
  end

  test "search is case-insensitive" do
    sign_in_as(users(:admin))
    visit projects_path

    find('input[data-search-target="input"]').fill_in with: "MAIN"
    assert_selector "article.project-card:not([hidden])", count: 1
    assert_text "Main App"

    find('input[data-search-target="input"]').fill_in with: "marketing"
    assert_selector "article.project-card:not([hidden])", count: 1
    assert_text "Marketing Site"
  end

  test "shows empty state when no matches and clears via button" do
    sign_in_as(users(:admin))
    visit projects_path

    find('input[data-search-target="input"]').fill_in with: "zzz-nothing"

    assert_text "No projects found"
    assert_text '"zzz-nothing"'

    click_button "Clear search"

    assert_no_text "No projects found"
    assert_selector "article.project-card:not([hidden])", count: 2
  end
end
