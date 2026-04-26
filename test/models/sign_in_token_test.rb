require "test_helper"

class SignInTokenTest < ActiveSupport::TestCase
  test "auto-generates token and expiry" do
    sign_in_token = users(:admin).sign_in_tokens.create!
    assert sign_in_token.token.present?
    assert sign_in_token.expires_at > Time.current
  end

  test "fresh scope excludes expired tokens" do
    fresh_tokens = SignInToken.fresh
    assert_includes fresh_tokens, sign_in_tokens(:fresh)
    assert_not_includes fresh_tokens, sign_in_tokens(:expired)
  end

  test "expired? matches expiry timestamp" do
    assert_not sign_in_tokens(:fresh).expired?
    assert sign_in_tokens(:expired).expired?
  end
end
