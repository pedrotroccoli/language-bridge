---
tags: [rails, 37signals, security, csrf, xss, ssrf]
---

# Security Checklist

> XSS, CSRF, SSRF, CSP, rate limiting.

See also: [[authentication]], [[webhooks]], [[multi-tenancy]]

---

## XSS: Always escape before `html_safe`
```ruby
"<span>#{h(user_input)}</span>".html_safe
```

## CSRF
- Don't HTTP cache pages with forms
- Sec-Fetch-Site header as additional check:
```ruby
def safe_fetch_site?
  %w[same-origin same-site].include?(request.headers["Sec-Fetch-Site"]&.downcase)
end
```

## SSRF (for [[webhooks]])
- DNS pinning: resolve once, use pinned IP
- Block private networks (127.0.0.0/8, 10.0.0.0/8, 169.254.0.0/16)
- Validate at creation AND request time

## Content Security Policy
```ruby
config.content_security_policy do |policy|
  policy.script_src :self
  policy.base_uri :none
  policy.frame_ancestors :self
end
```
Nonce-based script loading for importmap.

## Rate Limiting (Rails 7.2+)
```ruby
rate_limit to: 10, within: 15.minutes, only: :create
```

## Authorization
```ruby
before_action :ensure_can_administer
def ensure_can_administer
  head :forbidden unless Current.user.admin?
end
```

## Multi-Tenancy Security
- Scope broadcasts by account
- Disconnect deactivated users via `remote_connections`
- Scope all queries through `Current.account`

## Action Text Sanitizer
Sync allowed tags in `after_initialize` — production eager loading bypasses config.
