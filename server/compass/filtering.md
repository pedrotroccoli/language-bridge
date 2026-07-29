---
tags: [compass, rails, filtering, stimulus]
see-also:
  - "[[controllers]]"
  - "[[stimulus]]"
  - "[[models]]"
---

# Filtering

## Filter Object Pattern - Evolution Journey (PRs #115, #116)

### Before: Anti-Pattern Controller

The controller was doing too much - mixing query logic with HTTP concerns:

```ruby
# Anti-pattern: controller doing filtering
class BubblesController < ApplicationController
  def index
    @cards = current_bucket.cards
    @cards = @cards.where(creator: current_user) if params[:mine]
    @cards = @cards.where(status: params[:status]) if params[:status].present?
    @cards = @cards.search(params[:query]) if params[:query].present?
    @cards = @cards.where(assignee_id: params[:assignee]) if params[:assignee].present?
    @cards = @cards.tagged_with(params[:tag]) if params[:tag].present?
    @cards = @cards.due_before(params[:due_before]) if params[:due_before].present?
    @cards = @cards.page(params[:page])
  end
end
```

### After: Clean Filter PORO

Extract filtering into a plain Ruby object:

```ruby
# app/models/bucket/bubble_filter.rb
class Bucket::BubbleFilter
  include Filter::Params

  attr_reader :bucket, :user, :params

  def initialize(bucket:, user:, params: {})
    @bucket = bucket
    @user = user
    @params = params.to_h.symbolize_keys
  end

  def cards
    scope = bucket.cards.visible_to(user)
    scope = filter_by_status(scope)
    scope = filter_by_creator(scope)
    scope = filter_by_assignee(scope)
    scope = filter_by_tag(scope)
    scope = filter_by_due_date(scope)
    scope = search(scope)
    scope
  end

  def any_active?
    params.except(:sort).values.any?(&:present?)
  end

  private

  def filter_by_status(scope)
    return scope unless params[:status].present?
    scope.where(status: params[:status])
  end

  def filter_by_creator(scope)
    return scope if params[:mine].blank?
    scope.where(creator: user)
  end

  def filter_by_assignee(scope)
    return scope unless params[:assignee].present?
    scope.where(assignee_id: params[:assignee])
  end

  def filter_by_tag(scope)
    return scope unless params[:tag].present?
    scope.tagged_with(params[:tag])
  end

  def filter_by_due_date(scope)
    return scope unless params[:due_before].present?
    scope.due_before(Date.parse(params[:due_before]))
  end

  def search(scope)
    return scope unless params[:query].present?
    scope.search(params[:query])
  end
end
```

The controller becomes trivial:

```ruby
class BubblesController < ApplicationController
  def index
    @filter = Bucket::BubbleFilter.new(
      bucket: current_bucket,
      user: current_user,
      params: filter_params
    )
    @cards = @filter.cards.page(params[:page])
  end

  private

  def filter_params
    params.permit(:status, :mine, :assignee, :tag, :due_before, :query, :sort)
  end
end
```

---

## Query Composition: Lazy Evaluation with Memoization

The `Filter#cards` method composes scopes lazily - ActiveRecord only hits the database when results are enumerated:

```ruby
class Bucket::BubbleFilter
  def cards
    @cards ||= begin
      scope = bucket.cards.visible_to(user)
      scope = apply_status_filter(scope)
      scope = apply_creator_filter(scope)
      scope = apply_assignee_filter(scope)
      scope = apply_tag_filter(scope)
      scope = apply_due_date_filter(scope)
      scope = apply_search(scope)
      scope = apply_sort(scope)
      scope
    end
  end

  private

  def apply_status_filter(scope)
    case params[:status]
    when "open"   then scope.open
    when "closed" then scope.closed
    when "archived" then scope.archived
    else scope.active # default: open cards
    end
  end

  def apply_creator_filter(scope)
    return scope unless params[:mine].present?
    scope.where(creator: user)
  end

  def apply_assignee_filter(scope)
    return scope unless params[:assignee].present?
    if params[:assignee] == "none"
      scope.unassigned
    else
      scope.where(assignee_id: params[:assignee])
    end
  end

  def apply_tag_filter(scope)
    return scope unless params[:tag].present?
    scope.tagged_with(params[:tag])
  end

  def apply_due_date_filter(scope)
    return scope unless params[:due_before].present?
    scope.due_before(Date.parse(params[:due_before]))
  end

  def apply_search(scope)
    return scope unless params[:query].present?
    scope.search(params[:query])
  end

  def apply_sort(scope)
    case params[:sort]
    when "newest"  then scope.order(created_at: :desc)
    when "oldest"  then scope.order(created_at: :asc)
    when "due"     then scope.order(due_on: :asc)
    when "updated" then scope.order(updated_at: :desc)
    else scope.order(position: :asc)
    end
  end
end
```

Key insight: each `filter_by_*` method returns the scope unchanged if the param is blank, so filters compose cleanly without conditionals in the caller.

---

## URL-Based Filter State: Stateless Filtering

### Filter::Params Module

Filters are encoded in URL query parameters so they are bookmarkable, shareable, and work with back/forward navigation:

```ruby
# app/models/concerns/filter/params.rb
module Filter::Params
  extend ActiveSupport::Concern

  PERMITTED_PARAMS = %i[ status mine assignee tag due_before query sort ].freeze

  def as_params
    params.slice(*PERMITTED_PARAMS).compact_blank
  end

  def as_params_without(*keys)
    as_params.except(*keys)
  end

  def as_params_with(overrides)
    as_params.merge(overrides).compact_blank
  end

  def active_param?(key)
    params[key].present?
  end

  def active_params_count
    as_params.size
  end
end
```

### FilterScoped Concern

Applied to controllers that need filter state:

```ruby
# app/controllers/concerns/filter_scoped.rb
module FilterScoped
  extend ActiveSupport::Concern

  included do
    helper_method :current_filter
  end

  private

  def current_filter
    @current_filter ||= build_filter
  end

  def build_filter
    filter_class.new(
      bucket: current_bucket,
      user: current_user,
      params: filter_params
    )
  end

  def filter_class
    Bucket::BubbleFilter
  end

  def filter_params
    params.permit(*Filter::Params::PERMITTED_PARAMS)
  end
end
```

URLs look like: `/buckets/123/cards?status=open&assignee=456&tag=urgent`

---

## Filter Chips as Links (PR #138)

### Before: Form-Based (Anti-Pattern)

```erb
<%# Anti-pattern: form submission for filter removal %>
<%= form_with url: cards_path, method: :get do |f| %>
  <% current_filter.as_params.each do |key, value| %>
    <% unless key == :status %>
      <%= f.hidden_field key, value: value %>
    <% end %>
  <% end %>
  <button type="submit" class="filter-chip">
    Status: <%= params[:status] %> &times;
  </button>
<% end %>
```

### After: Link-Based (Clean)

Filter chips are simple links that remove one filter parameter:

```ruby
# app/helpers/filters_helper.rb
module FiltersHelper
  def filter_chip_tag(label:, param:, filter:, path:)
    remove_path = path.call(filter.as_params_without(param))

    link_to remove_path, class: "filter-chip" do
      concat content_tag(:span, label, class: "filter-chip__label")
      concat content_tag(:span, "Remove", class: "filter-chip__remove visually-hidden")
      concat icon("x", class: "filter-chip__icon")
    end
  end
end
```

```erb
<%# app/views/cards/_active_filters.html.erb %>
<div class="active-filters" role="list" aria-label="Active filters">
  <% if current_filter.active_param?(:status) %>
    <%= filter_chip_tag(
      label: "Status: #{params[:status].titleize}",
      param: :status,
      filter: current_filter,
      path: ->(p) { bucket_cards_path(current_bucket, p) }
    ) %>
  <% end %>

  <% if current_filter.active_param?(:assignee) %>
    <%= filter_chip_tag(
      label: "Assigned: #{User.find(params[:assignee]).name}",
      param: :assignee,
      filter: current_filter,
      path: ->(p) { bucket_cards_path(current_bucket, p) }
    ) %>
  <% end %>

  <% if current_filter.active_param?(:tag) %>
    <%= filter_chip_tag(
      label: "Tag: #{params[:tag]}",
      param: :tag,
      filter: current_filter,
      path: ->(p) { bucket_cards_path(current_bucket, p) }
    ) %>
  <% end %>

  <% if current_filter.any_active? %>
    <%= link_to "Clear all", bucket_cards_path(current_bucket),
      class: "filter-chip filter-chip--clear" %>
  <% end %>
</div>
```

### Testing Pattern

```ruby
class FiltersHelperTest < ActionView::TestCase
  test "filter_chip_tag renders link to remove filter" do
    filter = Bucket::BubbleFilter.new(
      bucket: buckets(:one),
      user: users(:one),
      params: { status: "open", tag: "urgent" }
    )

    html = filter_chip_tag(
      label: "Status: Open",
      param: :status,
      filter: filter,
      path: ->(p) { bucket_cards_path(buckets(:one), p) }
    )

    assert_includes html, "tag=urgent"
    refute_includes html, "status="
    assert_includes html, "filter-chip"
  end
end
```

---

## Stimulus Controllers for Filters (PR #567)

### Filter Controller with Debounce

Handles search input with debouncing to avoid excessive navigation:

```javascript
// app/javascript/controllers/filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form"]
  static values = {
    debounce: { type: Number, default: 300 }
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.submitForm()
    }, this.debounceValue)
  }

  submitForm() {
    const url = new URL(this.formTarget.action)
    const formData = new FormData(this.formTarget)

    for (const [key, value] of formData) {
      if (value) url.searchParams.set(key, value)
    }

    Turbo.visit(url.toString(), { action: "replace" })
  }

  clear() {
    this.inputTarget.value = ""
    this.submitForm()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

### Navigable List Controller with Keyboard Navigation

Provides keyboard navigation for filter dropdowns:

```javascript
// app/javascript/controllers/navigable_list_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.index = -1
  }

  keydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.selectNext()
        break
      case "ArrowUp":
        event.preventDefault()
        this.selectPrevious()
        break
      case "Enter":
        event.preventDefault()
        this.activateCurrent()
        break
      case "Space":
        if (this.index >= 0) {
          event.preventDefault()
          this.activateCurrent()
        }
        break
    }
  }

  selectNext() {
    if (this.index < this.itemTargets.length - 1) {
      this.index++
      this.highlightCurrent()
    }
  }

  selectPrevious() {
    if (this.index > 0) {
      this.index--
      this.highlightCurrent()
    }
  }

  highlightCurrent() {
    this.itemTargets.forEach((item, i) => {
      item.classList.toggle("navigable-list__item--highlighted", i === this.index)
      item.setAttribute("aria-selected", i === this.index)
    })
    this.itemTargets[this.index]?.scrollIntoView({ block: "nearest" })
  }

  activateCurrent() {
    const current = this.itemTargets[this.index]
    if (current) {
      const link = current.querySelector("a") || current
      link.click()
    }
  }
}
```

### View Integration with Dialog

```erb
<%# app/views/cards/_filter_bar.html.erb %>
<div class="filter-bar" data-controller="filter">
  <form action="<%= bucket_cards_path(current_bucket) %>"
        method="get"
        data-filter-target="form"
        data-turbo-action="replace">

    <input type="search"
           name="query"
           value="<%= params[:query] %>"
           placeholder="Search cards..."
           data-filter-target="input"
           data-action="input->filter#search"
           autocomplete="off" />

    <button type="button"
            data-action="filter#clear"
            class="filter-bar__clear"
            hidden>
      Clear
    </button>
  </form>

  <dialog id="filter-menu" class="filter-dialog">
    <div data-controller="navigable-list"
         data-action="keydown->navigable-list#keydown"
         role="listbox"
         aria-label="Filter options">

      <h3 class="filter-dialog__heading">Status</h3>
      <% %w[open closed archived].each do |status| %>
        <%= link_to bucket_cards_path(current_bucket,
              current_filter.as_params_with(status: status)),
            class: "filter-dialog__item",
            role: "option",
            data: { navigable_list_target: "item" } do %>
          <%= status.titleize %>
          <% if params[:status] == status %>
            <%= icon("check") %>
          <% end %>
        <% end %>
      <% end %>

      <h3 class="filter-dialog__heading">Assignee</h3>
      <% current_bucket.members.each do |member| %>
        <%= link_to bucket_cards_path(current_bucket,
              current_filter.as_params_with(assignee: member.id)),
            class: "filter-dialog__item",
            role: "option",
            data: { navigable_list_target: "item" } do %>
          <%= member.name %>
        <% end %>
      <% end %>
    </div>
  </dialog>
</div>
```

---

## Testing Filter Logic

```ruby
# test/models/bucket/bubble_filter_test.rb
class Bucket::BubbleFilterTest < ActiveSupport::TestCase
  setup do
    @bucket = buckets(:first)
    @user = users(:david)
  end

  test "cards returns only visible cards" do
    filter = build_filter
    cards = filter.cards

    assert cards.all? { |c| c.visible_to?(@user) }
  end

  test "cards filters by status" do
    filter = build_filter(status: "closed")

    assert filter.cards.all? { |c| c.closed? }
  end

  test "cards filters by creator when mine is set" do
    filter = build_filter(mine: "true")

    assert filter.cards.all? { |c| c.creator == @user }
  end

  test "cards filters by assignee" do
    assignee = users(:jason)
    filter = build_filter(assignee: assignee.id)

    assert filter.cards.all? { |c| c.assignee == assignee }
  end

  test "cards filters by tag" do
    filter = build_filter(tag: "bug")

    assert filter.cards.all? { |c| c.tags.include?("bug") }
  end

  test "permission boundaries are respected" do
    outsider = users(:outsider)
    filter = Bucket::BubbleFilter.new(
      bucket: @bucket,
      user: outsider,
      params: {}
    )

    assert_empty filter.cards
  end

  test "remembering equivalent filters" do
    filter_a = build_filter(status: "open", tag: "bug")
    filter_b = build_filter(tag: "bug", status: "open")

    assert_equal filter_a.digest_params, filter_b.digest_params
  end

  test "turning into params preserves only active filters" do
    filter = build_filter(status: "open", tag: "", assignee: nil)

    assert_equal({ status: "open" }, filter.as_params)
  end

  test "as_params_without removes specified keys" do
    filter = build_filter(status: "open", tag: "bug")

    result = filter.as_params_without(:status)
    assert_equal({ tag: "bug" }, result)
  end

  test "any_active? returns true when filters are applied" do
    assert build_filter(status: "open").any_active?
    refute build_filter.any_active?
  end

  private

  def build_filter(**params)
    Bucket::BubbleFilter.new(bucket: @bucket, user: @user, params: params)
  end
end
```

---

## Advanced Pattern: Filter Persistence with Digest

Filters can be "remembered" so users return to their last-used filter state:

```ruby
# app/models/concerns/filter/rememberable.rb
module Filter::Rememberable
  extend ActiveSupport::Concern

  def digest_params
    normalize_params(as_params)
  end

  def remember
    return unless any_active?

    remembered_filter = RememberedFilter.find_or_initialize_by(
      user: user,
      bucket: bucket,
      filterable_type: self.class.name
    )

    remembered_filter.update!(
      params: as_params,
      digest: digest_params
    )
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def remembered?
    RememberedFilter.exists?(
      user: user,
      bucket: bucket,
      filterable_type: self.class.name,
      digest: digest_params
    )
  end

  def restore
    remembered = RememberedFilter.find_by(
      user: user,
      bucket: bucket,
      filterable_type: self.class.name
    )

    return unless remembered

    @params = remembered.params.symbolize_keys
  end

  private

  def normalize_params(hash)
    sorted = hash.sort_by { |k, _| k.to_s }.to_h
    Digest::SHA256.hexdigest(sorted.to_json)
  end
end
```

```ruby
# app/models/remembered_filter.rb
class RememberedFilter < ApplicationRecord
  belongs_to :user
  belongs_to :bucket

  validates :filterable_type, presence: true
  validates :digest, presence: true
end
```

Usage in the controller:

```ruby
class BubblesController < ApplicationController
  include FilterScoped

  def index
    current_filter.restore if filter_params.empty?
    current_filter.remember if filter_params.any?

    @cards = current_filter.cards.page(params[:page])
  end
end
```

---

## Summary: 7 Key Takeaways

1. **Extract filter logic into POROs** - Controllers should delegate to filter objects, not contain query logic.
2. **Compose scopes lazily** - Each filter method returns the scope unchanged if inactive, enabling clean chaining.
3. **Use URL state for filters** - Query parameters make filters bookmarkable, shareable, and back-button compatible.
4. **Filter chips are links, not forms** - Simple `<a>` tags that reconstruct the URL without the removed parameter.
5. **Debounce search input** - Use Stimulus controllers to avoid excessive page navigations during typing.
6. **Keyboard navigation is essential** - ArrowDown/Up, Enter, and Space for filter menus via a reusable Stimulus controller.
7. **Persist filters with digests** - Normalize and hash filter params for idempotent storage with `RecordNotUnique` rescue for race conditions.
