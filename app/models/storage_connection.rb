# A workspace-level, named reference to an Active Storage service (defined in
# config/storage.yml). Backups (and future uploads) are written to the default
# connection's service. Credentials are NOT stored here — they come from the
# service config / environment (IAM role, ENV), the secure self-host path.
class StorageConnection < ApplicationRecord
  validates :name, presence: true
  validates :service_name, presence: true,
                           inclusion: { in: ->(_record) { available_services }, message: "is not a configured storage service" }

  scope :ordered, -> { order(:name) }

  after_save :unset_other_defaults, if: :is_default?

  # Service names configured in config/storage.yml (e.g. local, amazon, google).
  # storage.yml is keyed by service name (not by environment), so it's parsed
  # directly — rendering ERB first since it interpolates Rails.root / credentials.
  # Memoized: storage.yml is static for the life of the process.
  def self.available_services
    @available_services ||= begin
      path = Rails.root.join("config/storage.yml")
      if File.exist?(path)
        rendered = ERB.new(File.read(path)).result
        (YAML.safe_load(rendered, aliases: true) || {}).keys.map(&:to_s)
      else
        []
      end
    end
  rescue StandardError
    []
  end

  def self.default
    find_by(is_default: true)
  end

  # The default connection's service name, but only when that service is still
  # registered in Active Storage. Returns nil (use the app default) if the
  # operator removed the service from storage.yml, so backups don't fail.
  def self.default_service_name
    connection = default or return
    return connection.service_name if available_services.include?(connection.service_name)

    Rails.logger.warn("[StorageConnection] default service #{connection.service_name.inspect} is not configured; using the app default")
    nil
  end

  def summary
    [ bucket.presence, region.presence ].compact.join(" · ").presence || service_name
  end

  private
    def unset_other_defaults
      StorageConnection.where.not(id: id).update_all(is_default: false)
    end
end
