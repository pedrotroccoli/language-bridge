# Single-row global application settings (rate-limit defaults). Reached only
# through `Setting.current`, which caches the row so request-path readers (e.g.
# Rack::Attack) don't hit the database on every request. Saving busts the cache.
class Setting < ApplicationRecord
  CACHE_KEY = "app_setting".freeze

  after_commit :reset_cache

  def self.current
    Rails.cache.fetch(CACHE_KEY) { first || create! }
  end

  def self.reset_cache
    Rails.cache.delete(CACHE_KEY)
  end

  private
    def reset_cache
      self.class.reset_cache
    end
end
