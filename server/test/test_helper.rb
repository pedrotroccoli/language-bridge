ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "fileutils"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Materialized artifacts use deterministic storage keys (e.g.
    # "main-app/common/en.json"), so every parallel worker would otherwise write
    # to the SAME path under the shared tmp/storage and clobber each other. Give
    # each Disk service its own per-worker root so blobs stay isolated.
    parallelize_setup do |worker|
      %i[ test local ].each do |name|
        service = ActiveStorage::Blob.services.fetch(name) { nil }
        next unless service.respond_to?(:root)

        service.instance_variable_set(:@root, Rails.root.join("tmp/storage_#{name}_#{worker}").to_s)
      end
    end

    parallelize_teardown do |worker|
      %i[ test local ].each { |name| FileUtils.rm_rf(Rails.root.join("tmp/storage_#{name}_#{worker}")) }
    end

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
