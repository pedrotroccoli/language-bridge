class CreateTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :translations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :translation_key, null: false, foreign_key: true, type: :uuid, index: false
      t.references :locale, null: false, foreign_key: true, type: :uuid
      t.text :value
      t.references :author, null: true, foreign_key: { to_table: :users }, type: :uuid

      t.timestamps
    end

    add_index :translations, [ :translation_key_id, :locale_id ], unique: true
  end
end
