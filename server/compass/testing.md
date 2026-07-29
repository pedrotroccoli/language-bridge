---
tags: [compass, rails, testing, minitest, fixtures]
---

# Testing

See also: [[models]], [[controllers]]

## Minitest Over RSpec

37signals uses Minitest, not RSpec. Why:

- **Simpler.** Minitest is plain Ruby. Tests are methods, assertions are method calls. No DSL to learn, no magic matchers, no `subject`/`let`/`described_class` indirection.
- **Ships with Rails.** No extra gem, no configuration, no version conflicts. `rails new` gives you a working test suite.
- **Faster boot.** Minitest loads faster than RSpec. On a large app with thousands of tests, this matters.
- **Less ceremony.** A Minitest test is a method that starts with `test_`. An assertion is `assert_equal expected, actual`. That's it.

```ruby
# Minitest — plain Ruby, obvious, fast
class ProjectTest < ActiveSupport::TestCase
  test "requires a name" do
    project = Project.new(name: nil)
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end
end

# vs RSpec — DSL on top of DSL
RSpec.describe Project do
  describe "validations" do
    it "requires a name" do
      project = Project.new(name: nil)
      expect(project).not_to be_valid
      expect(project.errors[:name]).to include("can't be blank")
    end
  end
end
```

The Minitest version is shorter, clearer, and requires knowing less API.

## Fixtures Over Factories

Fixtures are loaded once into the database at the start of the test suite. They stay there for all tests, wrapped in transactions that roll back after each test.

Why fixtures over factories (FactoryBot):

- **Loaded once.** Fixtures are inserted once, not per-test. This is dramatically faster than creating objects in every test.
- **Deterministic IDs.** Fixture records have stable, predictable IDs derived from their label names. You can reference them reliably.
- **Encourage realistic data.** Fixtures represent your actual data model with all its relationships. Factories encourage creating minimal, disconnected objects.
- **No N+1 creation.** Factories with associations create entire object graphs per test. Fixtures share one graph.

```yaml
# test/fixtures/accounts.yml
basecamp:
  name: Basecamp

hey:
  name: HEY
```

```yaml
# test/fixtures/projects.yml
website_redesign:
  account: basecamp
  name: Website Redesign
  description: Redesign the marketing site

mobile_app:
  account: basecamp
  name: Mobile App
  description: Build the iOS app
```

## Fixture Relationships

Reference related fixtures by label name, not by ID:

```yaml
# test/fixtures/tasks.yml
design_homepage:
  project: website_redesign    # references projects(:website_redesign)
  title: Design homepage
  position: 1

build_navigation:
  project: website_redesign
  title: Build navigation
  position: 2

setup_ci:
  project: mobile_app
  title: Set up CI pipeline
  position: 1
```

Rails resolves the label to the fixture's ID automatically. Never hardcode IDs in fixtures — they're generated from the label hash and will differ across environments.

## ERB in Fixtures

Use ERB for dynamic values in fixtures:

```yaml
# test/fixtures/magic_links.yml
valid_link:
  identity: pedro
  code: "123456"
  created_at: <%= Time.current %>
  claimed_at:

expired_link:
  identity: pedro
  code: "654321"
  created_at: <%= 1.hour.ago %>
  claimed_at:

claimed_link:
  identity: pedro
  code: "111111"
  created_at: <%= 5.minutes.ago %>
  claimed_at: <%= 1.minute.ago %>
```

ERB is evaluated when fixtures are loaded. This is useful for time-sensitive records (magic links, tokens, subscriptions) that need relative timestamps.

## Test Structure

Follow a consistent structure: setup, action, assertion.

```ruby
class ProjectTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:basecamp)
    @project = projects(:website_redesign)
  end

  test "creates a project with tasks" do
    assert_difference -> { Project.count } => 1, -> { Task.count } => 2 do
      project = @account.projects.create!(
        name: "New Project",
        tasks_attributes: [
          { title: "First task", position: 1 },
          { title: "Second task", position: 2 }
        ]
      )

      assert_equal "New Project", project.name
      assert_equal 2, project.tasks.count
      assert_equal @account, project.account
    end
  end

  test "requires a name" do
    project = @account.projects.build(name: "")
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "scopes to account" do
    assert_includes @account.projects, @project
    assert_not_includes accounts(:hey).projects, @project
  end
end
```

`assert_difference` takes a hash of lambdas to counts, verifying that all counts change as expected within the block. This catches accidental side effects (creating too many records, missing cascades).

## Integration Tests

Integration tests (request tests) exercise the full stack from HTTP request to response:

```ruby
class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:basecamp)
    @project = projects(:website_redesign)
    sign_in_as identities(:pedro)
  end

  test "shows a project" do
    get account_project_url(@account, @project)

    assert_response :success
    assert_select "h1", @project.name
  end

  test "creates a project" do
    assert_difference "Project.count", 1 do
      post account_projects_url(@account), params: {
        project: { name: "New Project", description: "A new project" }
      }
    end

    assert_redirected_to account_project_url(@account, Project.last)
    follow_redirect!
    assert_select "h1", "New Project"
  end

  test "requires authentication" do
    sign_out

    get account_project_url(@account, @project)
    assert_redirected_to new_session_url
  end

  test "returns not found for other accounts" do
    other_project = projects(:hey_email)

    assert_raises ActiveRecord::RecordNotFound do
      get account_project_url(@account, other_project)
    end
  end
end
```

Note the `sign_in_as` helper (covered below). Integration tests should cover the happy path, authentication, authorization, and error cases.

## System Tests

System tests use Capybara to drive a real browser. Use them for complex UI interactions that can't be tested with integration tests:

```ruby
class ProjectBoardTest < ApplicationSystemTestCase
  setup do
    sign_in_as identities(:pedro)
    @account = accounts(:basecamp)
    @project = projects(:website_redesign)
  end

  test "reorders tasks by dragging" do
    visit account_project_url(@account, @project)

    first_task = find("[data-task-id='#{tasks(:design_homepage).id}']")
    second_task = find("[data-task-id='#{tasks(:build_navigation).id}']")

    # Drag first task below second task
    first_task.drag_to(second_task)

    # Verify new order persisted
    visit account_project_url(@account, @project)

    task_elements = all("[data-task-id]")
    assert_equal tasks(:build_navigation).id.to_s, task_elements[0]["data-task-id"]
    assert_equal tasks(:design_homepage).id.to_s, task_elements[1]["data-task-id"]
  end

  test "creates a task inline" do
    visit account_project_url(@account, @project)

    click_on "Add task"
    fill_in "Title", with: "New task from system test"
    click_on "Save"

    assert_text "New task from system test"
  end
end
```

System tests are slow. Use them sparingly — only for interactions that require JavaScript, drag-and-drop, or multi-step UI flows.

## Test Helpers

### SignInHelper

```ruby
# test/test_helpers/sign_in_helper.rb
module SignInHelper
  def sign_in_as(identity)
    session = identity.sessions.create!
    post session_url, params: { token: session.token }

    # For integration tests, set the cookie directly
    cookies[:session_token] = session.token
  end

  def sign_out
    delete session_url
  end
end

# test/test_helper.rb
class ActionDispatch::IntegrationTest
  include SignInHelper
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SignInHelper
end
```

### Parallelize and Fixtures

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  # Run tests in parallel with threads
  parallelize(workers: :number_of_processors)

  # Load all fixtures — don't cherry-pick
  fixtures :all

  # Add more helper methods here...
end
```

Always use `fixtures :all`. Cherry-picking fixtures (`fixtures :users, :projects`) leads to mysterious failures when a fixture references another fixture that isn't loaded. Load everything — it's fast because they're only inserted once.

## Testing Time

Use `travel_to` for tests that depend on the current time:

```ruby
class MagicLinkTest < ActiveSupport::TestCase
  test "expires after 15 minutes" do
    magic_link = magic_links(:valid_link)

    travel_to 14.minutes.from_now do
      assert_not magic_link.expired?
    end

    travel_to 16.minutes.from_now do
      assert magic_link.expired?
    end
  end

  test "unclaimed scope excludes expired links" do
    travel_to 20.minutes.from_now do
      assert_empty MagicLink.unclaimed
    end
  end
end
```

`travel_to` stubs `Time.current`, `Date.current`, and `DateTime.current` within the block, then restores them. Always use a block form to ensure time is restored even if the test fails.

## VCR for External APIs

Use VCR to record and replay HTTP interactions with external APIs:

```ruby
# test/test_helper.rb
VCR.configure do |config|
  config.cassette_library_dir = "test/cassettes"
  config.hook_into :webmock
  config.default_cassette_options = { record: :once }
  config.filter_sensitive_data("<STRIPE_KEY>") { Rails.application.credentials.dig(:stripe, :api_key) }
end
```

```ruby
class StripeChargeTest < ActiveSupport::TestCase
  test "creates a charge" do
    VCR.use_cassette("stripe/create_charge") do
      charge = StripeService.charge(
        amount: 1000,
        currency: "usd",
        source: "tok_visa"
      )

      assert charge.paid
      assert_equal 1000, charge.amount
    end
  end
end
```

VCR records the HTTP interaction on first run, then replays it on subsequent runs. This makes tests fast, deterministic, and runnable offline. Use `filter_sensitive_data` to scrub API keys from cassettes before committing them.

## Testing Jobs

### assert_enqueued_with

Test that a job is enqueued with the correct arguments:

```ruby
class ProjectNotificationTest < ActiveSupport::TestCase
  test "enqueues notification job on create" do
    assert_enqueued_with(job: NotifyMembersJob) do
      accounts(:basecamp).projects.create!(name: "New Project")
    end
  end

  test "enqueues with correct arguments" do
    project = accounts(:basecamp).projects.create!(name: "New Project")

    assert_enqueued_with(
      job: NotifyMembersJob,
      args: [project],
      queue: "default"
    ) do
      project.notify_members!
    end
  end
end
```

### perform_enqueued_jobs

Run enqueued jobs inline to test the full chain:

```ruby
class ProjectLifecycleTest < ActiveSupport::TestCase
  test "sends welcome email when project is created" do
    perform_enqueued_jobs do
      project = accounts(:basecamp).projects.create!(name: "New Project")

      assert_equal 1, ActionMailer::Base.deliveries.size
      email = ActionMailer::Base.deliveries.last
      assert_equal "New project created: New Project", email.subject
    end
  end
end
```

### assert_emails

Test email sending directly:

```ruby
class MagicLinkMailerTest < ActionMailer::TestCase
  test "sends sign-in email with code in subject" do
    identity = identities(:pedro)
    magic_link = identity.magic_links.create!

    assert_emails 1 do
      MagicLinkMailer.with(identity: identity, magic_link: magic_link).sign_in.deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [identity.email], email.to
    assert_includes email.subject, magic_link.code
  end
end
```

## When Tests Ship

Tests ship with features, in the same commit. There is no "add tests later" — if the feature isn't tested, it isn't done.

```
# A feature commit includes:
app/models/task.rb              # the model
app/controllers/tasks_controller.rb  # the controller
app/views/tasks/                # the views
test/models/task_test.rb        # model tests
test/controllers/tasks_controller_test.rb  # integration tests
test/system/tasks_test.rb       # system tests (if needed)
test/fixtures/tasks.yml         # fixture data
```

Every pull request includes tests. CI runs the full suite. A PR with failing tests does not merge.

## Key Principles

1. **Minitest, not RSpec.** Use what ships with Rails. It's simpler, faster, and has no learning curve beyond plain Ruby.

2. **Fixtures, not factories.** Load once, reference by label, share across all tests. Factories are slower and encourage unrealistic data.

3. **Test the behavior, not the implementation.** Assert what the user sees (responses, redirects, rendered content) not internal state. Test public interfaces, not private methods.

4. **Tests ship with features.** Same commit, same PR. No test debt. If it isn't tested, it isn't done.

5. **Keep tests fast.** Parallelize. Use fixtures (loaded once). Avoid system tests when integration tests suffice. Mock external APIs with VCR. A fast test suite gets run constantly; a slow one gets ignored.
