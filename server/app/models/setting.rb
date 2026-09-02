# Single-row global application settings (rate-limit defaults). Reached only
# through `Setting.current`, which caches the row so request-path readers (e.g.
# Rack::Attack) don't hit the database on every request. Saving busts the cache.
class Setting < ApplicationRecord
  CACHE_KEY = "app_setting".freeze

  validates :cli_token_limit, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 50 }
  validates :delivery_compression, inclusion: { in: DeliveryCompression::MODES }
  validates :delivery_base_url,
    allow_blank: true,
    format: { with: %r{\Ahttps?://[^\s/]+(/[^\s]*)?\z}i, message: "must start with http:// or https://" }

  after_commit :reset_cache

  # Public origin (scheme + host[:port], no trailing slash) shown in delivery
  # previews so users see the real CDN/ingress URL instead of the request host.
  # Blank = fall back to the incoming request's base URL.
  def delivery_base_url=(value)
    super(value.to_s.strip.chomp("/"))
  end

  def self.current
    Rails.cache.fetch(CACHE_KEY) { first || create! }
  end

  def self.reset_cache
    Rails.cache.delete(CACHE_KEY)
  end

  # Edit `allowed_origins` (a string array) as free text in the Workspace form:
  # one origin per line. Splits on any whitespace or comma, trims, drops blanks.
  def allowed_origins_text=(value)
    self.allowed_origins = value.to_s.split(/[\s,]+/).map(&:strip).reject(&:blank?)
  end

  def allowed_origins_text
    allowed_origins.join("\n")
  end

  private
    def reset_cache
      self.class.reset_cache
    end
end
