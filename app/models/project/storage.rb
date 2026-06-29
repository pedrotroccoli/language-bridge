# Where a project's objects (backups, uploads, delivery artifacts) are written:
# which storage connection it routes through and how object keys are prefixed.
module Project::Storage
  extend ActiveSupport::Concern

  included do
    belongs_to :storage_connection, optional: true
  end

  # The connection writes route through: the project's own, else the workspace
  # default. nil → the app's default Active Storage service.
  def effective_storage_connection
    storage_connection || StorageConnection.default
  end

  # Active Storage service name to route writes to, or nil for the app default.
  # The registry resolves sc_<id> on demand.
  def storage_service_name
    connection = effective_storage_connection
    connection.service_key if connection&.usable?
  end

  # Clean object key under the connection prefix + project upload_path.
  def storage_key(*parts)
    parts = [ upload_path, *parts ]
    if (connection = effective_storage_connection)
      connection.key_for(*parts)
    else
      parts.compact_blank.join("/").gsub(%r{/+}, "/").delete_prefix("/")
    end
  end
end
