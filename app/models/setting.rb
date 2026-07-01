# Single-row global application settings (rate-limit defaults). Reached only
# through `Setting.current`, which caches the row so request-path readers (e.g.
# Rack::Attack) don't hit the database on every request. Saving busts the cache.
class Setting < ApplicationRecord
  CACHE_KEY = "app_setting".freeze

  validates :delivery_compression, inclusion: { in: DeliveryCompression::MODES }

  after_commit :reset_cache

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
