ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# Signs a user in for integration tests by following a magic-link token.
module SignInHelper
  def sign_in_as(user)
    token = user.sign_in_tokens.create!
    get sign_in_with_token_path(token: token.token)
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end
