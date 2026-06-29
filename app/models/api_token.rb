require "digest"

# Per-project bearer token for client SDKs (i18next saveMissing, future write
# APIs). Only the SHA-256 digest is stored — the raw token is shown to the user
# exactly once at creation and is never recoverable afterward.
class ApiToken < ApplicationRecord
  SCOPES = %w[ save_missing read_only admin ].freeze

  belongs_to :project
  belongs_to :creator, class_name: "User", optional: true

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :scope, presence: true, inclusion: { in: SCOPES }

  scope :active, -> { where(revoked_at: nil) }

  # Build a token, returning [record, raw_token]. Persist the digest; hand the
  # caller the raw value to display once.
  def self.generate(project:, name:, scope:, creator: Current.user)
    raw = SecureRandom.urlsafe_base64(27) # ~36 url-safe chars
    record = create!(project:, name:, scope:, creator:, token_digest: digest(raw))
    [ record, raw ]
  end

  # Resolve an active token for a raw value within a project. Returns nil on a
  # blank/invalid/revoked token or a project mismatch.
  def self.authenticate(raw, project:)
    return if raw.blank? || project.nil?

    active.find_by(project_id: project.id, token_digest: digest(raw))
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end

  def revoked?
    revoked_at.present?
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end
end
