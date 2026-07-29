---
tags: [compass, rails, philosophy, anti-patterns]
see-also:
  - "[[philosophy]]"
  - "[[models]]"
  - "[[controllers]]"
---

# What They Avoid

## No Devise (~150 Lines Custom Passwordless)

Instead of the Devise gem (20k+ lines, dozens of modules), authentication is ~150 lines of custom passwordless code:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  generates_token_for :sign_in, expires_in: 15.minutes

  def send_sign_in_email
    token = generate_token_for(:sign_in)
    AuthenticationMailer.sign_in(self, token).deliver_later
  end
end
```

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  skip_before_action :authenticate

  def new
  end

  def create
    if user = User.find_by(email: params[:email])
      user.send_sign_in_email
    end

    redirect_to root_path, notice: "Check your email for a sign-in link"
  end

  def show
    user = User.find_by_token_for(:sign_in, params[:token])

    if user
      start_session_for(user)
      redirect_to root_path
    else
      redirect_to new_session_path, alert: "Invalid or expired link"
    end
  end

  def destroy
    end_session
    redirect_to root_path
  end

  private

  def start_session_for(user)
    session[:user_id] = user.id
  end

  def end_session
    session.delete(:user_id)
  end
end
```

Why: Devise is a framework within a framework. Passwordless auth with `generates_token_for` is simple, secure, and fits in your head.

---

## No Pundit/CanCanCan (Simple Predicate Methods on Models)

Authorization is done with plain predicate methods on the model:

```ruby
# app/models/bucket.rb
class Bucket < ApplicationRecord
  def accessible_by?(user)
    account.users.include?(user)
  end

  def administerable_by?(user)
    account.administrators.include?(user)
  end
end
```

```ruby
# app/models/card.rb
class Card < ApplicationRecord
  def visible_to?(user)
    bucket.accessible_by?(user)
  end

  def editable_by?(user)
    creator == user || bucket.administerable_by?(user)
  end

  def closeable_by?(user)
    editable_by?(user)
  end
end
```

```ruby
# app/controllers/cards_controller.rb
class CardsController < ApplicationController
  def update
    @card = current_bucket.cards.find(params[:id])

    unless @card.editable_by?(current_user)
      return redirect_to @card, alert: "Not authorized"
    end

    @card.update!(card_params)
    redirect_to @card
  end
end
```

Why: Authorization policies are domain logic. They belong on the model, not in a separate policy layer.

---

## No Service Objects (CardCloser Anti-Pattern vs Model Method)

### Anti-Pattern: Service Object

```ruby
# DON'T: app/services/card_closer.rb
class CardCloser
  def initialize(card, user)
    @card = card
    @user = user
  end

  def call
    return unless @card.closeable_by?(@user)

    @card.update!(status: :closed, closed_at: Time.current, closed_by: @user)
    @card.subscribers.each { |s| NotificationJob.perform_later(s, @card) }
    @card
  end
end
```

### Correct: Model Method

```ruby
# DO: app/models/card.rb
class Card < ApplicationRecord
  def close(by:)
    update!(status: :closed, closed_at: Time.current, closed_by: by)
  end
end
```

The controller calls `@card.close(by: current_user)`. Notifications are handled by model callbacks or separate concerns. No need for a `CardCloser` class that just wraps a method call.

Why: Service objects are a sign you're not putting behavior where it belongs. Models should contain domain logic.

---

## No Form Objects (Strong Parameters + Model Validations)

```ruby
# DON'T: app/forms/card_form.rb
class CardForm
  include ActiveModel::Model
  attr_accessor :title, :body, :assignee_id, :tag_list
  validates :title, presence: true
  # ... duplicating model validations
end
```

```ruby
# DO: strong parameters in the controller, validations on the model
class CardsController < ApplicationController
  def create
    @card = current_bucket.cards.create!(card_params)
    redirect_to @card
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def card_params
    params.require(:card).permit(:title, :body, :assignee_id, :tag_list)
  end
end
```

Why: Form objects duplicate validation logic. Strong parameters handle permitted attributes; the model handles validation.

---

## No Decorators/Presenters (View Helpers Instead)

```ruby
# DON'T: app/decorators/card_decorator.rb
class CardDecorator < SimpleDelegator
  def status_badge
    content_tag(:span, status.titleize, class: "badge badge--#{status}")
  end
end
```

```ruby
# DO: app/helpers/cards_helper.rb
module CardsHelper
  def card_status_badge(card)
    tag.span(card.status.titleize, class: "badge badge--#{card.status}")
  end

  def card_due_label(card)
    if card.overdue?
      tag.span("Overdue", class: "due-label due-label--overdue")
    elsif card.due_soon?
      tag.span("Due soon", class: "due-label due-label--soon")
    end
  end
end
```

Why: Helpers are built into Rails. Decorators add a layer of indirection for view logic that helpers handle naturally.

---

## No ViewComponent (ERB Partials)

```ruby
# DON'T: app/components/card_component.rb
class CardComponent < ViewComponent::Base
  def initialize(card:)
    @card = card
  end
end
```

```erb
<%# DO: app/views/cards/_card.html.erb %>
<div class="card" id="<%= dom_id(card) %>">
  <h3><%= link_to card.title, card %></h3>
  <p><%= card_status_badge(card) %></p>
  <p><%= card.creator.name %></p>
</div>
```

Why: ERB partials are Rails primitives. ViewComponent adds complexity for something that partials and helpers already solve.

---

## No GraphQL (REST + Turbo)

```ruby
# DON'T: app/graphql/types/card_type.rb
class Types::CardType < Types::BaseObject
  field :id, ID, null: false
  field :title, String, null: false
  # ...
end
```

```ruby
# DO: standard REST controllers with Turbo responses
class CardsController < ApplicationController
  def show
    @card = current_bucket.cards.find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
```

Why: REST with Turbo handles real-time UI updates without the complexity of a query language. Most apps don't need client-driven data fetching.

---

## No Sidekiq (Solid Queue)

```ruby
# Uses Solid Queue (built into Rails 8) instead of Sidekiq
# No Redis dependency for background jobs
# config/queue.yml is all you need

# config/recurring.yml
notification_delivery:
  class: Notification::DeliverAllJob
  schedule: every 5 minutes
```

Why: Solid Queue runs on the same database (no Redis). Recurring jobs via `recurring.yml` replace cron and sidekiq-cron. One less infrastructure dependency.

---

## No React/Vue/Frontend Framework (Turbo + Stimulus)

```erb
<%# Interactive UI with Turbo Frames and Stimulus %>
<%= turbo_frame_tag dom_id(@card) do %>
  <div data-controller="toggle">
    <button data-action="toggle#flip">Edit</button>
    <div data-toggle-target="content" hidden>
      <%= render "cards/form", card: @card %>
    </div>
  </div>
<% end %>
```

Why: Turbo + Stimulus handles 95% of interactivity needs. No build step, no node_modules, no API serialization layer.

---

## No Tailwind CSS (Native CSS with Cascade Layers)

```css
/* app/assets/stylesheets/application.css */
@layer base, components, utilities;

@layer components {
  .card {
    padding: var(--space-4);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
  }

  .badge {
    display: inline-flex;
    padding: var(--space-1) var(--space-2);
    font-size: var(--text-sm);
    border-radius: var(--radius-full);
  }

  .badge--open { background: var(--color-green-100); color: var(--color-green-800); }
  .badge--closed { background: var(--color-gray-100); color: var(--color-gray-800); }
}
```

Why: CSS has cascade layers, custom properties, nesting, and container queries natively. No utility class explosion, no build tool dependency.

---

## No RSpec (Minitest)

```ruby
# DON'T
RSpec.describe Card do
  describe "#close" do
    let(:card) { create(:card) }
    it { expect(card.close(by: user)).to be_truthy }
  end
end
```

```ruby
# DO
class CardTest < ActiveSupport::TestCase
  test "close sets status and timestamp" do
    card = cards(:open)
    card.close(by: users(:david))

    assert card.closed?
    assert_not_nil card.closed_at
  end
end
```

Why: Minitest is built into Rails. It's plain Ruby - no DSL to learn, no magic matchers, no `let` lazy evaluation surprises.

---

## No FactoryBot (Fixtures)

```yaml
# test/fixtures/cards.yml
open:
  title: Design homepage
  status: open
  bucket: first
  creator: david

closed:
  title: Old task
  status: closed
  closed_at: <%= 1.day.ago %>
  bucket: first
  creator: david
```

```ruby
# In tests
test "finds open cards" do
  assert_includes Card.open, cards(:open)
  assert_not_includes Card.open, cards(:closed)
end
```

Why: Fixtures are loaded once, making tests fast. Factory chains create hidden complexity and N+1 test setups. Fixtures force you to think about your data as a cohesive set.

---

## The Philosophy

> "The best code is no code at all. The second best is code that uses what's already there."

Every dependency is a liability. Every abstraction layer is a place where bugs hide. The Rails framework provides controllers, models, views, helpers, concerns, jobs, and mailers. Use them before reaching for gems. Write the simplest thing that could possibly work, then see if you even need more.

---

## What They DO Use

Gems they actually depend on (beyond Rails defaults):

- **propshaft** - Asset pipeline (Rails 8 default)
- **solid_queue** - Background jobs (Rails 8 default)
- **solid_cache** - Cache store (Rails 8 default)
- **solid_cable** - WebSocket (Rails 8 default)
- **turbo-rails** - Hotwire Turbo
- **stimulus-rails** - Hotwire Stimulus
- **kamal** - Deployment
- **thruster** - HTTP/2 proxy
- **image_processing** - Active Storage variants
- **bcrypt** - Password hashing (if needed)
- **rack-cors** - CORS for API
- **webmock** - HTTP stubbing in tests
- **capybara** - System tests
- **selenium-webdriver** - Browser testing
- **rubocop-rails-omakase** - Linting (DHH style)
