require "digest"

# Per-user personal access token (PAT) for the personal API / CLI. Prefixed
# `lb_pat_` so it's recognizable in logs and distinguishable from per-project
# ApiTokens. Only the SHA-256 digest is stored; the raw value is shown once.
# A user has at most one — regenerating replaces it.
class PersonalAccessToken < ApplicationRecord
  PREFIX = "lb_pat_".freeze

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true

  # Create (or replace) the user's token, returning the raw value to show once.
  def self.regenerate_for(user)
    raw = "#{PREFIX}#{SecureRandom.urlsafe_base64(27)}"
    transaction do
      where(user: user).delete_all
      create!(user: user, token_digest: digest(raw))
    end
    raw
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

  # The API scope a PAT grants mirrors its user's role, so a viewer's token
  # can't do more through the API than the user can in the app.
  ROLE_SCOPES = { "admin" => "admin", "translator" => "save_missing", "viewer" => "read_only" }.freeze

  def scope
    ROLE_SCOPES.fetch(user.role, "read_only")
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  # For display: the prefix plus a fixed dot run (the raw value is unrecoverable).
  def masked
    "#{PREFIX}#{"•" * 24}"
  end
end
