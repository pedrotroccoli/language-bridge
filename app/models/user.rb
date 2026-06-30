class User < ApplicationRecord
  ROLES = %w[ admin translator viewer ].freeze

  AVATAR_TYPES = %w[ image/png image/jpeg image/gif image/webp ].freeze
  AVATAR_MAX_BYTES = 2.megabytes

  has_many :sessions, dependent: :destroy
  has_many :sign_in_tokens, dependent: :destroy
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :inviter_id, dependent: :destroy

  has_one_attached :avatar

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  validates :name, length: { maximum: 100 }
  validate :acceptable_avatar

  # The name shown across the UI, falling back to the email's local-part.
  def display_name
    name.presence || email.to_s.split("@").first
  end

  # Up-to-two-letter initials from the display name, for the avatar fallback.
  def initials
    parts = display_name.split(/[\s._-]+/).reject(&:blank?)
    parts.first(2).map { |w| w[0] }.join.upcase.presence || "?"
  end

  def admin?      = role == "admin"
  def translator? = role == "translator"
  def viewer?     = role == "viewer"

  def can_administer_project?(_project = nil)
    admin?
  end

  def can_edit_translations?(_project = nil)
    admin? || translator?
  end

  def accessible_projects
    Project.all
  end

  private
    def acceptable_avatar
      return unless avatar.attached?

      errors.add(:avatar, "must be a PNG, JPEG, GIF, or WebP image") unless avatar.content_type.in?(AVATAR_TYPES)
      errors.add(:avatar, "is too large (2 MB max)") if avatar.byte_size > AVATAR_MAX_BYTES
    end
end
