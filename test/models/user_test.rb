require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid with email and role" do
    user = User.new(email: "new@example.com", role: "translator")
    assert user.valid?
  end

  test "requires email" do
    user = User.new(role: "translator")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "email is unique" do
    duplicate = User.new(email: users(:admin).email, role: "translator")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "normalizes email" do
    user = User.create!(email: "  Mixed@Example.COM  ", role: "viewer")
    assert_equal "mixed@example.com", user.email
  end

  test "role must be admin, translator, or viewer" do
    user = User.new(email: "x@example.com", role: "owner")
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end

  test "role defaults to translator" do
    user = User.create!(email: "default@example.com")
    assert_equal "translator", user.role
  end

  test "only admin can administer projects" do
    project = projects(:main_app)
    assert     users(:admin).can_administer_project?(project)
    assert_not users(:translator).can_administer_project?(project)
    assert_not users(:viewer).can_administer_project?(project)
  end

  test "can_administer_project? works without a project arg" do
    assert     users(:admin).can_administer_project?
    assert_not users(:translator).can_administer_project?
  end
end
