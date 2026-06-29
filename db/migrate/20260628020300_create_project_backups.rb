class CreateProjectBackups < ActiveRecord::Migration[8.1]
  def change
    create_table :project_backups, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :checksum, null: false
      t.integer :translations_count, null: false, default: 0
      t.bigint :byte_size, null: false, default: 0

      t.timestamps
    end

    add_index :project_backups, [ :project_id, :created_at ]
  end
end
