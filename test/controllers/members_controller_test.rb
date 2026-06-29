require "test_helper"

class MembersControllerTest < ActionDispatch::IntegrationTest
  test "admin lists members" do
    sign_in_as(users(:admin))
    get members_path
    assert_response :success
    assert_select "h2", "Members"
  end

  test "admin changes another member's role" do
    sign_in_as(users(:admin))
    patch member_path(users(:translator)), params: { user: { role: "viewer" } }
    assert_redirected_to members_path
    assert_equal "viewer", users(:translator).reload.role
  end

  test "admin cannot change own role" do
    sign_in_as(users(:admin))
    patch member_path(users(:admin)), params: { user: { role: "viewer" } }
    assert_equal "admin", users(:admin).reload.role
  end

  test "admin removes another member" do
    sign_in_as(users(:admin))
    assert_difference -> { User.count }, -1 do
      delete member_path(users(:viewer))
    end
    assert_redirected_to members_path
  end

  test "admin cannot remove self" do
    sign_in_as(users(:admin))
    assert_no_difference -> { User.count } do
      delete member_path(users(:admin))
    end
  end

  test "non-admin is blocked" do
    sign_in_as(users(:translator))
    get members_path
    assert_redirected_to root_path
  end
end
