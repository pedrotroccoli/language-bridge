class CreateStorageConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :storage_connections, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :service_name, null: false # an Active Storage service from config/storage.yml
      t.string :bucket
      t.string :region
      t.boolean :is_default, null: false, default: false

      t.timestamps
    end
  end
end
