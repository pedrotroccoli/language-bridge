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

  test "display_name falls back to the email local-part" do
    assert_equal "admin", users(:admin).display_name
    users(:admin).update!(name: "Ada Lovelace")
    assert_equal "Ada Lovelace", users(:admin).display_name
  end

  test "initials derive from the display name" do
    assert_equal "A", users(:admin).initials
    users(:admin).update!(name: "Ada Lovelace")
    assert_equal "AL", users(:admin).initials
  end

  test "name length is capped" do
    user = users(:admin)
    user.name = "x" * 101
    assert_not user.valid?
    assert_includes user.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "rejects an oversized or non-image avatar" do
    user = users(:admin)
    user.avatar.attach(io: StringIO.new("not an image"), filename: "a.txt", content_type: "text/plain")
    assert_not user.valid?
    assert_includes user.errors[:avatar], "must be a PNG, JPEG, GIF, or WebP image"
  end
end
