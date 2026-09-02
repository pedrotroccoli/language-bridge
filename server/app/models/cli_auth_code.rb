require "digest"

# A short-lived, one-time authorization code for the `lb login` loopback flow.
# The web approval page mints one for the signed-in user and redirects it to the
# CLI's loopback server; the CLI exchanges it (POST /api/v1/cli/token) for a
# freshly-minted personal access token. Only the digest is stored, and the code
# is single-use, so it never yields a token twice or after it expires.
class CliAuthCode < ApplicationRecord
  TTL = 5.minutes

  belongs_to :user

  validates :name, presence: true
  validates :code_digest, presence: true, uniqueness: true

  scope :usable, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  # The minted credential a redeemed code yields: the raw token (shown once) and
  # the user it belongs to.
  Redemption = Struct.new(:token, :user, keyword_init: true)

  # Issue a code for the user, returning the raw value to hand to the CLI once.
  # `scopes` are the capabilities the exchanged token will carry (clamped at
  # redeem time to the user's role).
  def self.issue(user:, name:, scopes: PersonalAccessToken::DEFAULT_SCOPES)
    raw = SecureRandom.urlsafe_base64(32)
    create!(user: user, name: name.to_s.presence || "cli", scopes: scopes, code_digest: digest(raw), expires_at: TTL.from_now)
    raw
  end

  # Redeem a raw code once: mint a personal access token (with the code's scope,
  # clamped to the user's role) and mark the code used. Returns a Redemption, or
  # nil for an unknown/expired/used code. Propagates PersonalAccessToken::LimitReached.
  def self.redeem(raw)
    return if raw.blank?

    code = usable.find_by(code_digest: digest(raw))
    return if code.nil?

    transaction do
      code.update!(used_at: Time.current)
      token = PersonalAccessToken.issue(user: code.user, name: code.name, scopes: code.scopes)
      Redemption.new(token: token, user: code.user)
    end
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end
end
