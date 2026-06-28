class CreateLocales < ActiveRecord::Migration[8.1]
  def change
    create_table :locales, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :code, null: false
      t.integer :translations_count, null: false, default: 0

      t.timestamps
    end

    add_index :locales, [ :project_id, :code ], unique: true
  end
end
