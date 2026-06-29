class AddFormatToProjectBackups < ActiveRecord::Migration[8.1]
  def change
    # The serialization format each snapshot was written in — a project's
    # schedule format can change, so each row records its own.
    add_column :project_backups, :format, :string, null: false, default: "json"
  end
end
