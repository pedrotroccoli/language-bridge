---
tags: [compass, rails, routing, rest, crud]
---

# Routing Patterns

> Everything is CRUD - resource-based routing over custom actions.

See also: [[controllers]], [[models]]

---

## The CRUD Principle

Every action maps to a CRUD verb. When something doesn't fit, **create a new resource**.

```ruby
# BAD: Custom actions on existing resource
resources :cards do
  post :close
  post :reopen
  post :archive
  post :gild
end

# GOOD: New resources for each state change
resources :cards do
  resource :closure      # POST to close, DELETE to reopen
  resource :goldness     # POST to gild, DELETE to ungild
  resource :not_now      # POST to postpone
  resource :pin          # POST to pin, DELETE to unpin
  resource :watch        # POST to watch, DELETE to unwatch
end
```

## Real Examples from Fizzy Routes

```ruby
resources :cards do
  scope module: :cards do
    resource :board
    resource :closure
    resource :column
    resource :goldness
    resource :image
    resource :not_now
    resource :pin
    resource :publish
    resource :reading
    resource :triage
    resource :watch

    resources :assignments
    resources :steps
    resources :taggings
    resources :comments do
      resources :reactions
    end
  end
end
```

## Noun-Based Resources

Turn verbs into nouns:

| Action | Resource |
|--------|----------|
| Close a card | `card.closure` |
| Watch a board | `board.watching` |
| Pin an item | `item.pin` |
| Publish a board | `board.publication` |
| Assign a user | `card.assignment` |
| Mark as golden | `card.goldness` |
| Postpone | `card.not_now` |

## Namespace for Context

```ruby
resources :boards do
  scope module: :boards do
    resource :publication
    resource :entropy
    resource :involvement

    namespace :columns do
      resource :not_now
      resource :stream
      resource :closed
    end
  end
end
```

## Use `resolve` for Custom URL Generation

```ruby
resolve "Comment" do |comment, options|
  options[:anchor] = ActionView::RecordIdentifier.dom_id(comment)
  route_for :card, comment.card, options
end

resolve "Notification" do |notification, options|
  polymorphic_url(notification.notifiable_target, options)
end
```

## Shallow Nesting

```ruby
resources :boards, shallow: true do
  resources :cards
end
# /boards/:board_id/cards      (index, new, create)
# /cards/:id                   (show, edit, update, destroy)
```

## Singular Resources

Use `resource` (singular) for one-per-parent resources:

```ruby
resources :cards do
  resource :closure
  resource :watching
  resource :goldness
end
```

## Module Scoping

```ruby
# scope module (no URL prefix)
resources :cards do
  scope module: :cards do
    resource :closure      # Cards::ClosuresController at /cards/:id/closure
  end
end

# namespace (adds URL prefix)
namespace :cards do
  resources :drops         # Cards::DropsController at /cards/drops
end
```

## Path-Based Multi-Tenancy

```ruby
scope "/:account_id" do
  resources :boards
  resources :cards
end
```

## Controller Mapping

```
app/controllers/
├── application_controller.rb
├── cards_controller.rb
├── cards/
│   ├── assignments_controller.rb
│   ├── closures_controller.rb
│   ├── columns_controller.rb
│   ├── drops_controller.rb
│   ├── goldnesses_controller.rb
│   ├── not_nows_controller.rb
│   ├── pins_controller.rb
│   ├── watches_controller.rb
│   └── comments/
│       └── reactions_controller.rb
├── boards_controller.rb
└── boards/
    ├── columns_controller.rb
    ├── entropies_controller.rb
    └── publications_controller.rb
```

## API Design: Same Controllers, Different Format

No separate API namespace - just `respond_to`:

```ruby
class Cards::ClosuresController < ApplicationController
  include CardScoped

  def create
    @card.close
    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.json { head :no_content }
    end
  end
end
```

### Consistent Response Codes

| Action | Success Code |
|--------|--------------|
| Create | `201 Created` + `Location` header |
| Update | `204 No Content` |
| Delete | `204 No Content` |

## Key Principles

1. **Every action is CRUD** - Create, read, update, or destroy something
2. **Verbs become nouns** - "close" becomes "closure" resource
3. **Shallow nesting** - Avoid deep URL nesting
4. **Singular when appropriate** - `resource` for one-per-parent
5. **Namespace for grouping** - Related controllers together
6. **Use `resolve`** - For polymorphic URL generation
7. **Same controller, different format** - No separate API controllers
