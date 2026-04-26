---
tags: [compass, rails, authentication, security]
---

# Authentication

See also: [[security]], [[controllers]], [[multi-tenancy]]

## Why Not Devise

37signals rolls custom authentication rather than using Devise. The entire authentication system is roughly 150 lines of code spread across a concern, a couple of models, and a controller. Why?

- Devise is a complex abstraction over something Rails already makes easy
- Password-based auth is being replaced by magic links and passkeys
- Custom auth is easier to understand, debug, and modify
- You own every line — no black-box middleware or callbacks
- It fits naturally into the Rails conventions you already know

When your auth is ~150 lines of code you wrote, there's nothing to "configure" — you just read it.

## Magic Link Flow

Instead of passwords, authentication uses a 6-digit magic link code sent via email:

1. User enters their email address on the sign-in form
2. System finds the `Identity` by email
3. A `MagicLink` record is created with a generated 6-digit code
4. The code is emailed to the user (code appears in the subject line for convenience)
5. User enters the 6-digit code on the verification form
6. System finds the magic link, consumes it (marks as used), and creates a `Session`
7. Session token is stored in a cookie scoped to the account path

```
User enters email
    → Identity lookup
    → MagicLink.create!(code: Code.generate)
    → MagicLinkMailer delivers code
    → User enters 6-digit code
    → MagicLink found & consumed
    → Session created
    → Cookie set
    → Redirect to app
```

## Identity Model

Identity is deliberately separated from User. A User belongs to an Account and represents membership. An Identity represents a person's authentication credentials across all accounts.

```ruby
# app/models/identity.rb
class Identity < ApplicationRecord
  has_many :users
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :access_tokens, dependent: :destroy

  has_many :accounts, through: :users

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def authenticate_with(code)
    magic_links.unclaimed.find_by(code: MagicLink::Code.sanitize(code))&.consume!
  end
end
```

Key insight: one Identity can have many Users across many Accounts. This is how multi-account support works — the person (Identity) is distinct from their membership (User) in any given Account.

## MagicLink Model

```ruby
# app/models/magic_link.rb
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes

  belongs_to :identity

  scope :unclaimed, -> { where(claimed_at: nil).where("created_at >= ?", EXPIRATION_TIME.ago) }

  before_create { self.code = Code.generate }

  def consume!
    update!(claimed_at: Time.current)
  end

  def expired?
    created_at < EXPIRATION_TIME.ago
  end

  module Code
    def self.generate
      SecureRandom.random_number(10**MagicLink::CODE_LENGTH).to_s.rjust(MagicLink::CODE_LENGTH, "0")
    end

    def self.sanitize(code)
      code.to_s.strip.gsub(/[^0-9]/, "").first(MagicLink::CODE_LENGTH)
    end
  end
end
```

The `Code` module handles generation (zero-padded random 6-digit number) and sanitization (strip whitespace, remove non-digits, truncate). The `consume!` pattern marks the link as used by setting `claimed_at`, and the `unclaimed` scope ensures codes can only be used once and only within the expiration window.

## Session Model

```ruby
# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :identity

  has_secure_token

  before_create { self.ip_address = Current.ip_address }
  before_create { self.user_agent = Current.user_agent }
end
```

Sessions are simple token holders. The token is stored in the cookie and used to look up the session on each request. IP address and user agent are recorded for audit purposes.

## Authentication Concern

This is the core of the system — a controller concern that provides a class-level DSL for declaring authentication rules and instance methods for session management.

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session
    helper_method :signed_in?
  end

  class_methods do
    # Skip authentication entirely — for sign-in pages, public pages
    def allow_unauthenticated_access(**options)
      skip_before_action :resume_session, **options
    end

    # Redirect away if already signed in — for sign-in/sign-up pages
    def require_unauthenticated_access(**options)
      allow_unauthenticated_access(**options)
      before_action :redirect_signed_in_user, **options
    end

    # Skip account scoping — for account selection, global pages
    def disallow_account_scope(**options)
      before_action :ensure_no_account_scope, **options
    end
  end

  private

    def resume_session
      if session_token = cookies.signed[:session_token]
        if session = Session.find_by(token: session_token)
          set_current_session(session)
        end
      end

      request_authentication unless signed_in?
    end

    def authenticate_by_bearer_token
      if token = request.headers["Authorization"]&.delete_prefix("Bearer ")
        if access_token = AccessToken.find_by(token: token)
          set_current_session(access_token.session)
        end
      end
    end

    def request_authentication
      session[:return_to_url] = request.url
      redirect_to new_session_url
    end

    def signed_in?
      Current.session.present?
    end

    def redirect_signed_in_user
      redirect_to root_url if signed_in?
    end

    def start_new_session_for(identity, account: nil)
      session = identity.sessions.create!
      set_current_session(session)

      cookies.signed.permanent[:session_token] = {
        value: session.token,
        httponly: true,
        same_site: :lax,
        path: account ? "/#{account.id}" : "/"
      }
    end

    def set_current_session(session)
      Current.session = session
      Current.identity = session.identity
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_token)
      redirect_to new_session_url
    end

    def ensure_no_account_scope
      # Override in account-scoped controllers
    end
end
```

The class-level DSL is the key design:
- `allow_unauthenticated_access` — skips the `resume_session` before_action entirely
- `require_unauthenticated_access` — also redirects already-signed-in users away
- `disallow_account_scope` — for controllers that operate outside an account context

## Sessions Controller

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    flash[:alert] = "Try again later."
    redirect_to new_session_url
  }

  def new
  end

  def create
    if identity = Identity.find_by(email: params[:email])
      magic_link = identity.magic_links.create!
      MagicLinkMailer.with(identity: identity, magic_link: magic_link).sign_in.deliver_later

      redirect_to new_magic_link_url(email: params[:email])
    else
      redirect_to new_session_url, alert: "No account found with that email."
    end
  end

  def destroy
    terminate_session
  end
end
```

Note the stacking of `disallow_account_scope` and `require_unauthenticated_access` — these are controller-level declarations that read like a spec of the controller's auth requirements. The `rate_limit` is built into Rails 7.2+ and protects against brute-force email enumeration.

## Magic Link Controller

```ruby
# app/controllers/magic_links_controller.rb
class MagicLinksController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    flash[:alert] = "Try again later."
    redirect_to new_session_url
  }

  def new
    @email = params[:email]
  end

  def create
    identity = Identity.find_by!(email: params[:email])

    if magic_link = identity.authenticate_with(params[:code])
      start_new_session_for(identity)
      redirect_to after_sign_in_url
    else
      redirect_to new_magic_link_url(email: params[:email]), alert: "Invalid or expired code."
    end
  end

  private

    def after_sign_in_url
      session.delete(:return_to_url) || root_url
    end
end
```

The controller verifies the email matches (looks up identity by email first), then delegates to `identity.authenticate_with(code)` which handles the sanitization and consumption of the magic link. The `after_sign_in_url` pattern restores the user to where they were trying to go before being redirected to sign in.

## Magic Link Mailer

```ruby
# app/mailers/magic_link_mailer.rb
class MagicLinkMailer < ApplicationMailer
  def sign_in
    @identity = params[:identity]
    @magic_link = params[:magic_link]

    mail(
      to: @identity.email,
      subject: "Your sign-in code is #{@magic_link.code}"
    )
  end
end
```

The code appears directly in the subject line. This is intentional — most people will see it in their notification/preview without even opening the email. The email body can contain additional context, but the subject line is the primary delivery mechanism.

## Current Context

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :identity
  attribute :user
  attribute :account

  attribute :ip_address
  attribute :user_agent

  def user
    identity&.users&.find_by(account: account) if account
  end
end
```

`Current` is the thread-safe global context for the request. It holds the session, identity, and derived user/account. The `user` method dynamically resolves based on the current account context.

## Multi-Account Support

One person (Identity) can belong to many accounts through User records:

```ruby
# An identity can have many users across accounts
identity.users          # => [User(account: basecamp), User(account: hey)]
identity.accounts       # => [Account(basecamp), Account(hey)]

# In a request context, Current resolves the right user
Current.identity = identity
Current.account = account
Current.user            # => the User for this identity + account combo
```

The Identity-User separation makes multi-account support natural. There is no "current user" problem — there's a current identity and a current account, and the user is derived.

## Session Path Scoping

Session cookies are scoped to the account path to prevent cross-account session leakage:

```ruby
# In start_new_session_for
cookies.signed.permanent[:session_token] = {
  value: session.token,
  httponly: true,
  same_site: :lax,
  path: account ? "/#{account.id}" : "/"
}
```

When a user signs into Account A, the cookie is set with `path: "/123"`. This means the browser only sends that cookie for requests under `/123/...`. Signing into Account B gets a separate cookie at `/456/...`. This avoids accidental cross-account access and allows simultaneous sessions in different accounts.

## Development Convenience

In development, the magic link code is flashed directly so you don't have to check email:

```ruby
# In SessionsController#create (development only)
if identity = Identity.find_by(email: params[:email])
  magic_link = identity.magic_links.create!
  MagicLinkMailer.with(identity: identity, magic_link: magic_link).sign_in.deliver_later

  # Show code in flash during development for convenience
  if Rails.env.local?
    flash[:magic_link_code] = magic_link.code
  end

  redirect_to new_magic_link_url(email: params[:email])
end
```

The safety net: this uses `Rails.env.local?` which returns true for both `development` and `test`, but never `production`. Even if this code accidentally shipped, the flash value wouldn't be displayed in production views (assuming you don't render `flash[:magic_link_code]` in production layouts).

## Key Principles

1. **Own your auth code.** ~150 lines is not worth a gem dependency. You'll understand every line, and you'll never fight a gem's assumptions about your data model.

2. **Separate identity from membership.** Identity = the person. User = their role in an account. This separation makes multi-account support trivial and avoids the "current_user belongs to one account" trap.

3. **Use magic links over passwords.** Passwords create support burden (resets, complexity rules, breaches). A 6-digit code sent to a verified email is simpler for users and developers.

4. **Make the auth DSL declarative.** Controllers should declare their auth requirements at the class level (`require_unauthenticated_access`, `allow_unauthenticated_access`) not bury auth logic in before_actions.

5. **Scope sessions to accounts.** Cookie path scoping prevents cross-account session leakage without complex token management.

6. **Rate limit authentication endpoints.** Use Rails' built-in `rate_limit` to protect sign-in and code verification endpoints from brute force attacks.
