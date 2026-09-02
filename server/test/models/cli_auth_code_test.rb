require "test_helper"

class CliAuthCodeTest < ActiveSupport::TestCase
  test "issue stores only the digest and redeem mints a token once" do
    raw = CliAuthCode.issue(user: users(:admin), name: "laptop")

    code = CliAuthCode.sole
    assert_not_equal raw, code.code_digest
    assert_equal "laptop", code.name

    redemption = CliAuthCode.redeem(raw)
    assert redemption.token.start_with?(PersonalAccessToken::PREFIX)
    assert_equal users(:admin), redemption.user
    assert_equal "laptop", users(:admin).personal_access_tokens.sole.name

    # Single-use: a second redeem yields nothing and mints no second token.
    assert_nil CliAuthCode.redeem(raw)
    assert_equal 1, users(:admin).personal_access_tokens.count
  end

  test "login mints a draft-writing token, never admin" do
    raw = CliAuthCode.issue(user: users(:admin), name: "laptop") # admin, yet…
    token = PersonalAccessToken.authenticate(CliAuthCode.redeem(raw).token)
    assert_equal %w[ read read_drafts write ], token.scopes
    assert_not token.grants?("admin")
  end

  test "redeem rejects unknown, blank, and expired codes" do
    assert_nil CliAuthCode.redeem(nil)
    assert_nil CliAuthCode.redeem("nope")

    raw = CliAuthCode.issue(user: users(:admin), name: "laptop")
    CliAuthCode.sole.update!(expires_at: 1.minute.ago)
    assert_nil CliAuthCode.redeem(raw)
  end

  test "redeem propagates the token limit" do
    Setting.current.update!(cli_token_limit: 1)
    PersonalAccessToken.issue(user: users(:admin), name: "existing")
    raw = CliAuthCode.issue(user: users(:admin), name: "laptop")

    assert_raises(PersonalAccessToken::LimitReached) { CliAuthCode.redeem(raw) }
  end
end
