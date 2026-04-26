require "test_helper"

class InvitationsFlowTest < ActionDispatch::IntegrationTest
  test "admin creates invitation and email is sent" do
    sign_in_as(users(:admin))

    assert_difference "Invitation.count", 1 do
      perform_enqueued_jobs do
        assert_emails 1 do
          post invitations_path, params: { invitation: { email: "newhire@example.com", role: "translator" } }
        end
      end
    end

    assert_redirected_to invitations_path
  end

  test "non-admin cannot create invitation" do
    sign_in_as(users(:translator))
    post invitations_path, params: { invitation: { email: "x@example.com", role: "translator" } }
    assert_redirected_to root_path
    assert_match(/Admins only/, flash[:alert])
  end

  test "anonymous can view valid invitation page" do
    get accept_invitation_path(token: invitations(:pending).token)
    assert_response :success
  end

  test "anonymous accepts invitation, creates user, signs in" do
    invitation = invitations(:pending)

    assert_difference "User.count", 1 do
      post claim_invitation_path(token: invitation.token)
    end

    user = User.find_by(email: invitation.email)
    assert_equal "translator", user.role
    assert_redirected_to root_path
    assert invitation.reload.accepted?
  end

  test "expired invitation cannot be accepted" do
    assert_no_difference "User.count" do
      post claim_invitation_path(token: invitations(:expired).token)
    end
    assert_redirected_to sign_in_path
  end

  test "already-accepted invitation cannot be reused" do
    invitations(:pending).update!(accepted_at: Time.current)
    assert_no_difference "User.count" do
      post claim_invitation_path(token: invitations(:pending).token)
    end
    assert_redirected_to sign_in_path
  end

  test "admin can revoke pending invitation" do
    sign_in_as(users(:admin))
    assert_difference "Invitation.count", -1 do
      delete invitation_path(invitations(:pending))
    end
    assert_redirected_to invitations_path
  end

  private
    def sign_in_as(user)
      token = user.sign_in_tokens.create!
      get sign_in_with_token_path(token: token.token)
    end
end
