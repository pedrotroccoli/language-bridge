# Cross-Origin Resource Sharing (rack-cors).
#
# Two distinct surfaces with opposite trust models:
#
#   /cdn/*  — public i18n delivery. Browsers on ANY origin load these bundles
#             via i18next http-backend, so origins are open ("*") but read-only
#             (GET/HEAD). ETag is exposed so clients can do conditional GETs.
#
#   /api/*  — private API (saveMissing, future write endpoints). Allowed origins
#             are managed from the Workspace settings panel (Setting#allowed_
#             origins), not an env var, so self-hosters can change them without a
#             redeploy. The per-request origins block reads the cached Setting
#             row; an empty list (the default) rejects every cross-origin API
#             request — fail closed. DB-not-ready at boot also rejects.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # Public delivery CDN — any origin, read-only.
  allow do
    origins "*"
    resource "/cdn/*",
      headers: :any,
      methods: %i[ get head options ],
      expose: %w[ ETag ]
  end

  # Private API — restricted to the origins configured in Workspace settings.
  # Evaluated per request (only for /api/* paths); Setting.current is cached.
  allow do
    origins do |source, _env|
      Setting.current.allowed_origins.include?(source)
    rescue ActiveRecord::ActiveRecordError
      false
    end
    resource "/api/*",
      headers: :any,
      methods: %i[ get post put patch delete options ]
  end
end
