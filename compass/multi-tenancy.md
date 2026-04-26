---
tags: [rails, 37signals, multi-tenancy, middleware]
---

# Multi-Tenancy

> URL path-based tenancy. No wildcard DNS/SSL. Shared database with `account_id`.

See also: [[authentication]], [[database]], [[actioncable]], [[email]]

---

## Path-Based Middleware
```ruby
class AccountSlug::Extractor
  def call(env)
    request = ActionDispatch::Request.new(env)
    if request.path_info =~ PATH_INFO_MATCH
      request.engine_script_name = request.script_name = $1
      request.path_info = $'.empty? ? "/" : $'
      env["fizzy.external_account_id"] = AccountSlug.decode($2)
    end
    if env["fizzy.external_account_id"]
      account = Account.find_by(external_account_id: env["fizzy.external_account_id"])
      Current.with_account(account) { @app.call(env) }
    else
      Current.without_account { @app.call(env) }
    end
  end
end
```

## ActiveJob Tenant Preservation
```ruby
module FizzyActiveJobExtensions
  def initialize(...)
    super
    @account = Current.account
  end
  def serialize
    super.merge({ "account" => @account&.to_gid })
  end
  def perform_now
    account.present? ? Current.with_account(account) { super } : super
  end
end
```

## Always Scope Lookups
```ruby
# Bad
@comment = Comment.find(params[:comment_id])
# Good
@comment = Current.account.comments.find(params[:comment_id])
# Better
@bubble = Current.user.accessible_bubbles.find(params[:bubble_id])
```

## Recurring Jobs: Iterate All Tenants
```ruby
class AutoPopAllDueJob < ApplicationJob
  def perform
    ApplicationRecord.with_each_tenant { |t| Bubble.auto_pop_all_due }
  end
end
```

## Session Cookie Path Scoping
Path scope cookies to prevent cross-tenant clobbering.

## Architecture Decision
Path-based tenancy with shared database (not database-per-tenant).
URLs: `/1234567/boards/123`. Simpler than subdomains for local dev.
