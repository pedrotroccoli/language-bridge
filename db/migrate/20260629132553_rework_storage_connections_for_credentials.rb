class ReworkStorageConnectionsForCredentials < ActiveRecord::Migration[8.1]
  def change
    # `service` is the storage kind the connection talks to. Replaces the old
    # `service_name` ref into config/storage.yml — connections are now
    # self-contained service definitions with their own (optional) credentials.
    add_column :storage_connections, :service, :string, null: false, default: "local"
    add_column :storage_connections, :endpoint, :string                       # S3-compatible override
    add_column :storage_connections, :inherit_credentials, :boolean, null: false, default: false
    add_column :storage_connections, :access_key_id, :string                  # AR-encrypted in model
    add_column :storage_connections, :secret_access_key, :string              # AR-encrypted in model

    # Backfill `service` from the legacy service_name where possible, then drop
    # the dependency on storage.yml service names.
    up_only do
      execute <<~SQL
        UPDATE storage_connections
        SET service = CASE
          WHEN service_name IN ('amazon', 's3')      THEN 's3'
          WHEN service_name IN ('google', 'gcs')     THEN 'gcs'
          WHEN service_name IN ('microsoft', 'azure') THEN 'azure'
          ELSE 'local'
        END
      SQL
    end

    change_column_null :storage_connections, :service_name, true
  end
end
