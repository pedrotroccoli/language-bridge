class CreateTranslationArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :translation_artifacts, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :project,   null: false, type: :uuid, foreign_key: true
      t.references :namespace, null: false, type: :uuid, foreign_key: true
      t.references :locale,    null: false, type: :uuid, foreign_key: true
      t.string   :checksum, null: false
      t.datetime :built_at, null: false

      t.timestamps
    end

    add_index :translation_artifacts, [ :namespace_id, :locale_id ], unique: true
  end
end
