require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "auto-generates secure token" do
    session = users(:admin).sessions.create!
    assert session.token.present?
    assert_equal 36, session.token.length
  end

  test "belongs to user" do
    assert_equal users(:admin), sessions(:admin_session).user
  end
end
