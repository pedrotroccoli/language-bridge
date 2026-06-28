class CreateTranslationKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :translation_keys, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.references :namespace, null: false, foreign_key: true, type: :uuid
      t.string :key, null: false
      t.integer :translations_count, null: false, default: 0

      t.timestamps
    end

    add_index :translation_keys, [ :project_id, :namespace_id, :key ], unique: true
  end
end
