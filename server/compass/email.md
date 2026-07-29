---
tags: [rails, 37signals, email, mailers, smtp]
---

# Email

> Multi-tenant mailers, timezone handling, SMTP resilience.

See also: [[multi-tenancy]], [[notifications]], [[background-jobs]]

---

## Multi-Tenant URLs
```ruby
def default_url_options
  Current.account ? super.merge(script_name: Current.account.slug) : super
end
```

## Timezone Awareness
```ruby
def deliver
  user.in_time_zone do
    Current.with_account(user.account) { send_email }
  end
end
```

## SVG Fallbacks
Replace SVG avatars with HTML/CSS initials — most email clients block SVG.

## SMTP via ENV
```ruby
config.action_mailer.smtp_settings = {
  address: ENV["SMTP_ADDRESS"],
  port: ENV.fetch("SMTP_PORT", "587").to_i,
  # ...
}
```

## Error Handling
- Retry: `Net::OpenTimeout`, `Net::SMTPServerBusy` (polynomial backoff)
- Swallow: `550 5.1.1` (unknown), `552 5.6.0` (too large)
- Apply globally: `ActionMailer::MailDeliveryJob.include SmtpDeliveryErrorHandling`

## Batch: `ActiveJob.perform_all_later` for bulk enqueue

## One-Click Unsubscribe (RFC 8058)
```ruby
headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
headers["List-Unsubscribe"] = "<#{unsubscribe_url(token: token)}>"
```

## Layout: table-based, inline styles, `mso-line-height-rule: exactly` for Outlook
