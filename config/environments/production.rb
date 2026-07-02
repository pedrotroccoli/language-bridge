require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # Delivery/storage targets are configured at runtime via the UI (StorageConnection).
  config.active_storage.service = :local

  # Assume access is through an SSL-terminating reverse proxy (ingress / load
  # balancer). Enabled by default; set RAILS_ASSUME_SSL=false to opt out.
  config.assume_ssl = ENV.fetch("RAILS_ASSUME_SSL", "true") == "true"

  # Force all access over SSL, use HSTS, and secure cookies. On by default; set
  # RAILS_FORCE_SSL=false when TLS is not terminated in front of the app.
  config.force_ssl = ENV.fetch("RAILS_FORCE_SSL", "true") == "true"

  # Skip http-to-https redirect for the default health check endpoint so probes work.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Host used by links generated in mailer templates (set APP_HOST=your.domain).
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com") }

  # Outgoing SMTP server, configured entirely from the environment. When
  # SMTP_PASSWORD is unset, delivery errors are swallowed so the app still boots.
  config.action_mailer.raise_delivery_errors = ENV["SMTP_PASSWORD"].present?
  config.action_mailer.delivery_method = :smtp
  # tls/authentication default to the Resend-style secure setup, but are
  # overridable so a plain test relay (e.g. Mailhog on :1025) can be used:
  # SMTP_TLS=false and SMTP_AUTHENTICATION= (empty) disable both.
  config.action_mailer.smtp_settings = {
    address:        ENV.fetch("SMTP_HOST", "smtp.resend.com"),
    port:           ENV.fetch("SMTP_PORT", 465).to_i,
    user_name:      ENV.fetch("SMTP_USERNAME", "resend"),
    password:       ENV["SMTP_PASSWORD"],
    authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").presence&.to_sym,
    tls:            ActiveModel::Type::Boolean.new.cast(ENV.fetch("SMTP_TLS", "true"))
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # DNS rebinding / Host-header protection. Populate from RAILS_HOSTS (comma
  # separated, e.g. "app.example.com,.example.com"). A leading "." is expanded to
  # a subdomain wildcard regexp. Empty = allow all hosts (fine behind a trusted
  # ingress that already routes by host).
  if (hosts = ENV.fetch("RAILS_HOSTS", "").split(",").map(&:strip).reject(&:empty?)).any?
    config.hosts = hosts.map { |h| h.start_with?(".") ? /.*#{Regexp.escape(h)}\z/ : h }
    # Skip DNS rebinding protection for the default health check endpoint.
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  end
end
