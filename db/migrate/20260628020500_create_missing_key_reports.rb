class CreateMissingKeyReports < ActiveRecord::Migration[8.1]
  def change
    create_table :missing_key_reports, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :namespace, null: false
      t.string :key, null: false
      t.integer :hits, null: false, default: 0
      t.jsonb :locales, null: false, default: []
      t.datetime :first_reported_at
      t.datetime :last_reported_at

      t.timestamps
    end

    add_index :missing_key_reports, [ :project_id, :namespace, :key ], unique: true
    add_index :missing_key_reports, [ :project_id, :last_reported_at ]
  end
end
