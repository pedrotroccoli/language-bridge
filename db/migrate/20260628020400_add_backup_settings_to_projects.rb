class AddBackupSettingsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :backups_enabled,       :boolean, null: false, default: true
    add_column :projects, :backup_frequency,      :string,  null: false, default: "daily" # daily|weekly|monthly
    add_column :projects, :backup_retention,      :integer, null: false, default: 30
    add_column :projects, :backup_include_drafts, :boolean, null: false, default: false

    # Provenance of each snapshot, for the AUTO/MANUAL badge.
    add_column :project_backups, :source, :string, null: false, default: "manual"
  end
end
