require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  test "valid with email, role, inviter" do
    invitation = Invitation.new(email: "new@example.com", role: "translator", inviter: users(:admin))
    assert invitation.valid?
  end

  test "auto-generates token and expiry" do
    invitation = Invitation.create!(email: "x@example.com", role: "viewer", inviter: users(:admin))
    assert invitation.token.present?
    assert invitation.expires_at > Time.current
  end

  test "rejects invitation for existing user email" do
    invitation = Invitation.new(email: users(:admin).email, role: "translator", inviter: users(:admin))
    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "is already registered"
  end

  test "role must be in allowed list" do
    invitation = Invitation.new(email: "x@example.com", role: "owner", inviter: users(:admin))
    assert_not invitation.valid?
  end

  test "claimable? when not accepted and not expired" do
    assert invitations(:pending).claimable?
    assert_not invitations(:expired).claimable?
  end

  test "accept! creates user and marks invitation accepted" do
    invitation = invitations(:pending)
    user = nil
    assert_difference "User.count", 1 do
      user = invitation.accept!
    end
    assert_equal invitation.email, user.email
    assert_equal invitation.role, user.role
    assert invitation.reload.accepted?
  end

  test "pending scope excludes accepted and expired" do
    invitations(:pending).update!(accepted_at: Time.current)
    pending = Invitation.pending
    assert_not_includes pending, invitations(:pending)
    assert_not_includes pending, invitations(:expired)
  end
end
