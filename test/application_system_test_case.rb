require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  def sign_in_as(user)
    visit sign_in_path
    token = user.sign_in_tokens.create!
    visit sign_in_with_token_path(token: token.token)
  end
end
