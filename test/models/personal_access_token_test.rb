require "test_helper"

class PersonalAccessTokenTest < ActiveSupport::TestCase
  test "regenerate_for returns a prefixed raw token and stores only the digest" do
    raw = PersonalAccessToken.regenerate_for(users(:admin))

    assert raw.start_with?(PersonalAccessToken::PREFIX)
    token = users(:admin).reload.personal_access_token
    assert_not_equal raw, token.token_digest
    assert_equal PersonalAccessToken.digest(raw), token.token_digest
  end

  test "regenerate_for replaces the previous token" do
    old_raw = PersonalAccessToken.regenerate_for(users(:admin))
    new_raw = PersonalAccessToken.regenerate_for(users(:admin))

    assert_equal 1, PersonalAccessToken.where(user: users(:admin)).count
    assert_nil PersonalAccessToken.authenticate(old_raw)
    assert_equal users(:admin), PersonalAccessToken.authenticate(new_raw).user
  end

  test "authenticate ignores blank, unprefixed, or unknown tokens" do
    assert_nil PersonalAccessToken.authenticate(nil)
    assert_nil PersonalAccessToken.authenticate("no_prefix_here")
    assert_nil PersonalAccessToken.authenticate("#{PersonalAccessToken::PREFIX}bogus")
  end

  test "authenticate stamps last_used_at" do
    raw = PersonalAccessToken.regenerate_for(users(:admin))
    assert_nil users(:admin).reload.personal_access_token.last_used_at
    PersonalAccessToken.authenticate(raw)
    assert_not_nil users(:admin).reload.personal_access_token.last_used_at
  end
end
