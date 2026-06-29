class RemoveLegacyServiceNameFromStorageConnections < ActiveRecord::Migration[8.1]
  # The `service` column (added in ReworkStorageConnectionsForCredentials) replaced
  # the old config/storage.yml `service_name` ref, which is now unreferenced.
  def change
    remove_column :storage_connections, :service_name, :string
  end
end
