require "digest"

# Per-user personal access token (PAT) for the personal API / CLI. Prefixed
# `lb_pat_` so it's recognizable in logs and distinguishable from per-project
# ApiTokens. Only the SHA-256 digest is stored; the raw value is shown once.
#
# A user may hold several named tokens (one per machine, minted by `lb login`),
# capped per user by Setting#cli_token_limit. Each token carries its own set of
# capabilities (see TokenScopes), never exceeding what the user's role allows —
# so a login token can be limited to writing drafts even when its owner is admin.
class PersonalAccessToken < ApplicationRecord
  include TokenScopes

  PREFIX = "lb_pat_".freeze

  # The capabilities each role may grant (a subset of TokenScopes::CAPABILITIES).
  ROLE_CAPABILITIES = {
    "admin" => %w[ read read_drafts write admin ],
    "translator" => %w[ read read_drafts write ],
    "viewer" => %w[ read ]
  }.freeze

  # What `lb login` requests: a draft-writing contributor token, no admin.
  DEFAULT_SCOPES = %w[ read read_drafts write ].freeze

  # Raised when issuing would exceed the workspace's per-user cap.
  class LimitReached < StandardError; end

  belongs_to :user

  validates :name, presence: true
  validates :scopes, presence: true
  validates :token_digest, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }

  # The capabilities a user is allowed to grant (their role cap).
  def self.grantable_scopes(user)
    ROLE_CAPABILITIES.fetch(user.role, %w[ read ])
  end

  # Keep only requested capabilities the user may grant, in canonical order. An
  # empty result stays empty and fails the presence validation on issue, rather
  # than silently granting read.
  def self.clamp_scopes(user, requested)
    CAPABILITIES & Array(requested).map(&:to_s) & grantable_scopes(user)
  end

  # Issue a new named token for the user, returning the raw value to show once.
  # Scopes are clamped to the user's role cap. Enforces the per-user count cap;
  # raises LimitReached when full.
  def self.issue(user:, name:, scopes: DEFAULT_SCOPES)
    transaction do
      # Serialize concurrent issues for one user so the count cap can't be
      # raced past by parallel logins.
      user.lock!
      if user.personal_access_tokens.count >= Setting.current.cli_token_limit
        raise LimitReached, "You already have the maximum of #{Setting.current.cli_token_limit} tokens."
      end

      raw = "#{PREFIX}#{SecureRandom.urlsafe_base64(27)}"
      create!(user: user, name: name.to_s.presence || "token", scopes: clamp_scopes(user, scopes), token_digest: digest(raw))
      raw
    end
  end

  # Resolve a PAT from a raw bearer value, stamping last-used. Returns nil for a
  # blank value, one lacking the prefix, or an unknown digest.
  def self.authenticate(raw)
    return if raw.blank? || !raw.start_with?(PREFIX)

    find_by(token_digest: digest(raw))&.tap(&:touch_last_used!)
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  # For display: the prefix plus a fixed dot run (the raw value is unrecoverable).
  def masked
    "#{PREFIX}#{"•" * 24}"
  end
end
