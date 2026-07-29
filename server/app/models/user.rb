class User < ApplicationRecord
  ROLES = %w[ admin translator viewer ].freeze

  AVATAR_TYPES = %w[ image/png image/jpeg image/gif image/webp ].freeze
  AVATAR_MAX_BYTES = 2.megabytes

  has_many :sessions, dependent: :destroy
  has_many :sign_in_tokens, dependent: :destroy
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :inviter_id, dependent: :destroy

  has_one :personal_access_token, dependent: :destroy

  # Served via Active Storage's default :redirect delivery (302 to the blob),
  # so bytes don't stream through the app. A downscaled, preprocessed :thumb
  # variant (active-storage.md) is deferred until an image processor (libvips)
  # is available in the deploy image — avatars are capped at 2 MB meanwhile.
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
    # Validate only when a new avatar is being attached (not on every save), and
    # sniff the real MIME from the bytes rather than trusting the client-declared
    # Content-Type, which is spoofable.
    def acceptable_avatar
      change = attachment_changes["avatar"]
      return if change.nil?

      errors.add(:avatar, "is too large (2 MB max)") if change.blob.byte_size > AVATAR_MAX_BYTES
      errors.add(:avatar, "must be a PNG, JPEG, GIF, or WebP image") unless sniffed_avatar_type(change.attachable).in?(AVATAR_TYPES)
    end

    # Detect the MIME from the uploaded bytes (form upload, IO, or io-hash).
    def sniffed_avatar_type(attachable)
      io =
        if attachable.respond_to?(:open) then attachable.open
        elsif attachable.respond_to?(:read) then attachable
        elsif attachable.is_a?(Hash) then attachable[:io]
        end
      return "application/octet-stream" if io.nil?

      Marcel::MimeType.for(io)
    ensure
      io.rewind if io.respond_to?(:rewind)
    end
end
