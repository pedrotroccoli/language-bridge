require "test_helper"

class InvitationMailerTest < ActionMailer::TestCase
  test "invite" do
    invitation = invitations(:pending)
    mail = InvitationMailer.with(invitation: invitation).invite
    assert_equal "You're invited to Language Bridge", mail.subject
    assert_equal [ invitation.email ], mail.to
    assert_match invitation.token, mail.body.encoded
    assert_match invitation.role, mail.body.encoded
  end
end
