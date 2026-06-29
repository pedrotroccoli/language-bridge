# Rate limiting for the inbound write path (saveMissing) and public delivery.
#
# Limits are NOT hardcoded: they come from the global Setting row, optionally
# overridden per-project, so self-hosters can tune them from the Workspace and
# Project Settings panels without a redeploy. Per-(kind,slug) limits are cached
# for 60s so throttling stays off the database hot path.
Rails.application.config.middleware.use Rack::Attack

class Rack::Attack
  Rack::Attack.cache.store = Rails.cache

  MISSING_PATH  = %r{\A/api/v1/projects/([^/]+)/missing/?\z}
  DELIVERY_PATH = %r{\A/cdn/([^/]+)/}

  # Returns { limit:, period: } for a request when throttling applies, else nil
  # (unknown path, throttling disabled, or DB not yet available at boot).
  def self.rule_for(req, kind, path_regex)
    match = req.path.match(path_regex)
    return unless match

    setting = Setting.current
    return unless setting.rate_limiting_enabled

    limit = effective_limit(match[1], kind, setting)
    return unless limit

    period = kind == :missing ? setting.missing_rate_period : setting.delivery_rate_period
    { limit: limit, period: period }
  rescue ActiveRecord::ActiveRecordError
    nil
  end

  def self.effective_limit(slug, kind, setting)
    Rails.cache.fetch("rate_limit:#{kind}:#{slug}", expires_in: 60.seconds) do
      project  = Project.find_by(slug: slug)
      override = kind == :missing ? project&.missing_rate_limit : project&.delivery_rate_limit
      override || (kind == :missing ? setting.missing_rate_limit : setting.delivery_rate_limit)
    end
  end

  throttle("missing/ip",
           limit:  ->(req) { req.env["rack_attack.rule"][:limit] },
           period: ->(req) { req.env["rack_attack.rule"][:period] }) do |req|
    if req.post? && (rule = rule_for(req, :missing, MISSING_PATH))
      req.env["rack_attack.rule"] = rule
      req.ip
    end
  end

  throttle("delivery/ip",
           limit:  ->(req) { req.env["rack_attack.rule"][:limit] },
           period: ->(req) { req.env["rack_attack.rule"][:period] }) do |req|
    if req.get? && (rule = rule_for(req, :delivery, DELIVERY_PATH))
      req.env["rack_attack.rule"] = rule
      req.ip
    end
  end

  # 429 with Retry-After (seconds until the throttle window resets).
  self.throttled_responder = lambda do |req|
    match    = req.env["rack.attack.match_data"] || {}
    period   = match[:period] || 60
    epoch    = match[:epoch_time] || 0
    reset_in = period - (epoch % period)
    [ 429,
      { "Content-Type" => "application/json", "Retry-After" => reset_in.to_s },
      [ { error: "Rate limit exceeded. Retry later." }.to_json ] ]
  end
end

# Log throttle events.
ActiveSupport::Notifications.subscribe("rack.attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  next unless req.env["rack.attack.match_type"] == :throttle

  Rails.logger.warn(
    "[Rack::Attack] throttled name=#{req.env['rack.attack.matched']} ip=#{req.ip} path=#{req.path}"
  )
end

# Throttling depends on a working cache + DB; keep it out of the test suite.
Rack::Attack.enabled = false if Rails.env.test?
