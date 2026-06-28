class AddProjectToTranslations < ActiveRecord::Migration[8.1]
  def up
    add_reference :translations, :project, type: :uuid, foreign_key: true, index: true, null: true

    # Backfill the denormalized project from each translation's key.
    execute <<~SQL.squish
      UPDATE translations
      SET project_id = translation_keys.project_id
      FROM translation_keys
      WHERE translations.translation_key_id = translation_keys.id
    SQL

    change_column_null :translations, :project_id, false
  end

  def down
    remove_reference :translations, :project, foreign_key: true
  end
end
