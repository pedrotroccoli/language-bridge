class AddUploadsAndBackupFormatToProjects < ActiveRecord::Migration[8.1]
  def change
    # Per-project storage connection (nil = workspace default). Uploads + backups
    # for this project are written to the chosen connection's bucket.
    add_reference :projects, :storage_connection, type: :uuid, null: true, foreign_key: { on_delete: :nullify }

    # Path prefix (after the bucket) where this project's uploads are written.
    add_column :projects, :upload_path, :string, null: false, default: ""

    # Upload rule overrides — when false, the workspace defaults apply.
    add_column :projects, :upload_override, :boolean, null: false, default: false
    add_column :projects, :upload_max_bytes, :bigint                       # nil = inherit
    add_column :projects, :upload_allowed_formats, :string, array: true    # nil = inherit

    # Backup export format and the UTC hour (0-23) the daily/weekly/monthly run fires.
    add_column :projects, :backup_format, :string, null: false, default: "json"
    add_column :projects, :backup_time_of_day, :integer, null: false, default: 3
  end
end
