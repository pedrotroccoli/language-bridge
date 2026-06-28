class CreateTranslationVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :translation_versions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :translation, null: false, foreign_key: true, type: :uuid
      t.text :value
      t.references :author, null: true, foreign_key: { to_table: :users }, type: :uuid

      t.timestamps
    end

    add_index :translation_versions, [ :translation_id, :created_at ]
  end
end
