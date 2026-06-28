class CreateTranslationPublications < ActiveRecord::Migration[8.1]
  def change
    create_table :translation_publications, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :translation, null: false, foreign_key: true, type: :uuid, index: false
      t.references :publisher, null: true, foreign_key: { to_table: :users }, type: :uuid

      t.timestamps
    end

    add_index :translation_publications, :translation_id, unique: true
  end
end
