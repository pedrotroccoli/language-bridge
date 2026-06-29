class AddUploadDefaultsToSettings < ActiveRecord::Migration[8.1]
  def change
    # Workspace-wide upload defaults, inherited by every project unless overridden.
    add_column :settings, :upload_max_bytes, :bigint, null: false, default: 5.megabytes
    add_column :settings, :upload_allowed_formats, :string, array: true, null: false,
               default: %w[ json csv xliff ]
  end
end
