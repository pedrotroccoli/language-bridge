require "test_helper"

class NamespaceTest < ActiveSupport::TestCase
  test "valid with project and name" do
    namespace = Namespace.new(project: projects(:main_app), name: "auth")
    assert namespace.valid?
  end

  test "requires project" do
    namespace = Namespace.new(name: "auth")
    assert_not namespace.valid?
    assert_includes namespace.errors[:project], "must exist"
  end

  test "requires name" do
    namespace = Namespace.new(project: projects(:main_app))
    assert_not namespace.valid?
    assert_includes namespace.errors[:name], "can't be blank"
  end

  test "rejects invalid name formats" do
    %w[Common .leading-dot has\ space UPPER weird@char -leading-dash].each do |bad|
      namespace = Namespace.new(project: projects(:main_app), name: bad)
      assert_not namespace.valid?, "expected #{bad.inspect} to be invalid"
      assert namespace.errors[:name].any?
    end
  end

  test "accepts valid name formats" do
    project = Project.create!(name: "Format Test")
    %w[auth auth-flow marketing.cta v2_buttons a 1 a.b.c].each do |good|
      namespace = Namespace.new(project: project, name: good)
      assert namespace.valid?, "expected #{good.inspect} to be valid (errors: #{namespace.errors.full_messages})"
    end
  end

  test "name unique per project" do
    duplicate = Namespace.new(project: projects(:main_app), name: namespaces(:main_app_common).name)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "same name allowed across different projects" do
    namespace = Namespace.new(project: projects(:marketing_site), name: namespaces(:main_app_marketing).name)
    assert namespace.valid?
  end

  test "destroying project with namespaces is restricted" do
    project = Project.create!(name: "Restricted")
    project.namespaces.create!(name: "auth")
    assert_raises(ActiveRecord::DeleteRestrictionError) { project.destroy! }
  end

  test "counter cache increments project.namespaces_count on create" do
    project = Project.create!(name: "Counter Test")
    assert_difference -> { project.reload.namespaces_count }, 1 do
      project.namespaces.create!(name: "auth")
    end
  end

  test "counter cache decrements project.namespaces_count on destroy" do
    project = Project.create!(name: "Counter Decrement")
    namespace = project.namespaces.create!(name: "auth")
    assert_difference -> { project.reload.namespaces_count }, -1 do
      namespace.destroy!
    end
  end

  test "alphabetically scope orders by name asc" do
    project = projects(:main_app)
    assert_equal project.namespaces.alphabetically.pluck(:name), project.namespaces.pluck(:name).sort
  end
end
