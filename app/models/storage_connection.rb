# A workspace-level storage destination for backups and uploads. Self-contained:
# each connection carries its own service kind (Local / S3 / GCS / Azure), bucket
# and — for the cloud services — either credentials stored encrypted at rest, or
# an instruction to inherit them from the environment / instance IAM role.
#
# A connection materializes into an Active Storage service registered under the
# name "sc_<id>" (see StorageConnectionRegistry). Blobs are attached with that
# service name, so any process can resolve the service on demand from the DB.
class StorageConnection < ApplicationRecord
  SERVICES = %w[ local s3 gcs azure ].freeze
  CLOUD_SERVICES = %w[ s3 gcs azure ].freeze

  # Stored encrypted. For S3 these are the access key id + secret; for GCS the
  # project id + service-account JSON; for Azure the account name + access key.
  encrypts :access_key_id
  encrypts :secret_access_key

  has_many :projects, dependent: :nullify

  validates :name, presence: true
  validates :service, inclusion: { in: SERVICES }
  validates :bucket, presence: true, if: :cloud?
  validate  :credentials_present, if: :needs_credentials?

  scope :ordered, -> { order(:name) }

  after_save :unset_other_defaults, if: :is_default?

  def self.default
    find_by(is_default: true)
  end

  # Is there at least one usable cloud bucket? Drives the global "no storage
  # configured" banner and the uploads/backups gating.
  def self.usable_cloud_exists?
    where(service: CLOUD_SERVICES).any?(&:usable?)
  end

  def cloud?
    CLOUD_SERVICES.include?(service)
  end

  # Cloud connection that stores its own keys (vs. inheriting from env/IAM).
  def needs_credentials?
    cloud? && !inherit_credentials
  end

  # Can this connection actually be used to route a blob? Local always; cloud
  # needs a bucket and either inherited or stored credentials.
  def usable?
    return true unless cloud?

    bucket.present? && (inherit_credentials || (access_key_id.present? && secret_access_key.present?))
  end

  # Active Storage service name this connection registers under.
  def service_key
    "sc_#{id}"
  end

  # Join the connection's base prefix with the given key parts into a clean,
  # leading-slash-free object key (e.g. prefix "poc" + "backups/x" → "poc/backups/x").
  def key_for(*parts)
    [ prefix.presence, *parts ].compact_blank.join("/").gsub(%r{/+}, "/").delete_prefix("/")
  end

  # Short, human description for the connection list.
  def summary
    [ bucket.presence, region.presence ].compact.join(" · ").presence || service_label
  end

  def service_label
    { "local" => "Local disk", "s3" => "Amazon S3", "gcs" => "Google Cloud Storage", "azure" => "Azure Blob" }
      .fetch(service, service)
  end

  # Build the Active Storage service object for this connection. Active Storage's
  # configurator requires the adapter gem lazily based on the `service:` key.
  def build_active_storage_service
    service_object = ActiveStorage::Service.configure(service.to_sym, { service.to_sym => service_config })
    service_object.name = service_key.to_sym
    service_object
  end

  # Eagerly register this connection's service in the Active Storage registry so a
  # blob can be validated + attached under its service_key. (The registry's lazy
  # resolver only covers the no-block fetch path used by downloads — Blob's
  # service_name validation passes a block, which would otherwise just fail.)
  def register_service!
    services = ActiveStorage::Blob.services.instance_variable_get(:@services)
    services[service_key.to_sym] ||= build_active_storage_service
  end

  private
    def service_config
      case service
      when "local"
        { service: "Disk", root: Rails.root.join("storage").to_s }
      when "s3"
        config = { service: "S3", bucket: bucket, region: region.presence }
        if endpoint.present?
          config[:endpoint] = endpoint
          config[:force_path_style] = true # S3-compatible (MinIO, R2, Spaces)
        end
        unless inherit_credentials
          config[:access_key_id] = access_key_id
          config[:secret_access_key] = secret_access_key
        end
        config.compact
      when "gcs"
        # access_key_id -> project id, secret_access_key -> service-account JSON.
        config = { service: "GCS", bucket: bucket, project: access_key_id.presence }
        config[:credentials] = parsed_gcs_credentials unless inherit_credentials
        config.compact
      when "azure"
        # access_key_id -> storage account name, secret_access_key -> access key.
        { service: "AzureStorage", storage_account_name: access_key_id, storage_access_key: secret_access_key, container: bucket }
      end
    end

    # GCS accepts a path or a parsed hash; the secret holds the raw JSON keyfile.
    def parsed_gcs_credentials
      JSON.parse(secret_access_key.to_s)
    rescue JSON::ParserError
      secret_access_key
    end

    def credentials_present
      errors.add(:access_key_id, "is required") if access_key_id.blank?
      errors.add(:secret_access_key, "is required") if secret_access_key.blank?
    end

    def unset_other_defaults
      StorageConnection.where.not(id: id).update_all(is_default: false)
    end
end
