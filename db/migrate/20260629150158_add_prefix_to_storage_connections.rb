class AddPrefixToStorageConnections < ActiveRecord::Migration[8.1]
  def change
    # Optional base path within the bucket that every key (backups, uploads, and
    # the connection-test probe) is written under. Lets a path-scoped IAM policy
    # restrict the credentials to one prefix.
    add_column :storage_connections, :prefix, :string, null: false, default: ""
  end
end
