require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "valid with name" do
    project = Project.new(name: "New App")
    assert project.valid?
  end

  test "requires name" do
    project = Project.new
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "auto-generates slug from name on create" do
    project = Project.create!(name: "Cool New App")
    assert_equal "cool-new-app", project.slug
  end

  test "appends suffix when slug already exists" do
    Project.create!(name: "Duplicate App")
    project = Project.create!(name: "Duplicate App")
    assert_equal "duplicate-app-2", project.slug
  end

  test "slug is unique" do
    duplicate = Project.new(name: "Other", slug: projects(:main_app).slug)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "to_param returns slug" do
    assert_equal projects(:main_app).slug, projects(:main_app).to_param
  end

  test "alphabetically scope orders by name asc" do
    assert_equal Project.alphabetically.pluck(:name), Project.all.pluck(:name).sort
  end

  test "counter caches default to zero" do
    project = Project.create!(name: "Counters")
    assert_equal 0, project.locales_count
    assert_equal 0, project.namespaces_count
    assert_equal 0, project.translation_keys_count
  end
end
