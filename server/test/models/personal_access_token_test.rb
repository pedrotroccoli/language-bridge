require "test_helper"

class PersonalAccessTokenTest < ActiveSupport::TestCase
  test "issue returns a prefixed raw token and stores only the digest" do
    raw = PersonalAccessToken.issue(user: users(:admin), name: "laptop")

    assert raw.start_with?(PersonalAccessToken::PREFIX)
    token = users(:admin).personal_access_tokens.sole
    assert_equal "laptop", token.name
    assert_not_equal raw, token.token_digest
    assert_equal PersonalAccessToken.digest(raw), token.token_digest
  end

  test "issue lets a user hold several named tokens" do
    a = PersonalAccessToken.issue(user: users(:admin), name: "laptop")
    b = PersonalAccessToken.issue(user: users(:admin), name: "desktop")

    assert_equal 2, users(:admin).personal_access_tokens.count
    assert_equal users(:admin), PersonalAccessToken.authenticate(a).user
    assert_equal users(:admin), PersonalAccessToken.authenticate(b).user
  end

  test "issue enforces the workspace-wide per-user cap" do
    Setting.current.update!(cli_token_limit: 2)
    2.times { |i| PersonalAccessToken.issue(user: users(:admin), name: "t#{i}") }

    assert_raises(PersonalAccessToken::LimitReached) do
      PersonalAccessToken.issue(user: users(:admin), name: "over")
    end
    assert_equal 2, users(:admin).personal_access_tokens.count
  end

  test "issue requires a name" do
    assert_raises(ActiveRecord::RecordInvalid) do
      PersonalAccessToken.create!(user: users(:admin), token_digest: "x")
    end
  end

  test "authenticate ignores blank, unprefixed, or unknown tokens" do
    assert_nil PersonalAccessToken.authenticate(nil)
    assert_nil PersonalAccessToken.authenticate("no_prefix_here")
    assert_nil PersonalAccessToken.authenticate("#{PersonalAccessToken::PREFIX}bogus")
  end

  test "issue defaults to draft-writing capabilities without admin" do
    token = PersonalAccessToken.authenticate(PersonalAccessToken.issue(user: users(:admin), name: "laptop"))
    assert_equal %w[ read read_drafts write ], token.scopes
    assert_not token.grants?("admin")
    assert token.grants?("write")
  end

  test "issue clamps the requested capabilities to the user's role cap" do
    wanted = %w[ read read_drafts write admin ]
    admin = PersonalAccessToken.authenticate(PersonalAccessToken.issue(user: users(:admin), name: "a", scopes: wanted))
    translator = PersonalAccessToken.authenticate(PersonalAccessToken.issue(user: users(:translator), name: "t", scopes: wanted))
    viewer = PersonalAccessToken.authenticate(PersonalAccessToken.issue(user: users(:viewer), name: "v", scopes: wanted))

    assert_equal %w[ read read_drafts write admin ], admin.scopes
    assert_equal %w[ read read_drafts write ], translator.scopes, "translator cannot grant admin"
    assert_equal %w[ read ], viewer.scopes, "viewer is capped to read"
  end

  test "grantable_scopes reflects the role cap" do
    assert_equal %w[ read read_drafts write admin ], PersonalAccessToken.grantable_scopes(users(:admin))
    assert_equal %w[ read read_drafts write ], PersonalAccessToken.grantable_scopes(users(:translator))
    assert_equal %w[ read ], PersonalAccessToken.grantable_scopes(users(:viewer))
  end

  test "an unknown capability fails validation" do
    token = PersonalAccessToken.new(user: users(:admin), name: "x", scopes: %w[ read bogus ], token_digest: "d")
    assert_not token.valid?
    assert token.errors[:scopes].any?
  end

  test "authenticate stamps last_used_at" do
    raw = PersonalAccessToken.issue(user: users(:admin), name: "laptop")
    assert_nil users(:admin).personal_access_tokens.sole.last_used_at
    PersonalAccessToken.authenticate(raw)
    assert_not_nil users(:admin).personal_access_tokens.sole.reload.last_used_at
  end
end
