require "test_helper"

class SignInMailerTest < ActionMailer::TestCase
  test "magic_link" do
    token = users(:admin).sign_in_tokens.create!
    mail = SignInMailer.with(token: token).magic_link
    assert_equal "Your Language Bridge sign-in link", mail.subject
    assert_equal [ users(:admin).email ], mail.to
    assert_match token.token, mail.body.encoded
  end
end
