class AddIsSourceToLocales < ActiveRecord::Migration[8.1]
  def change
    # The source locale is the translate-from origin (machine translation, the
    # add-language helper, fuzzy detection). At most one per project — enforced
    # by a partial unique index so the "one source" rule lives in the database,
    # not just the model.
    add_column :locales, :is_source, :boolean, null: false, default: false
    add_index :locales, :project_id, unique: true, where: "is_source",
              name: "index_locales_on_one_source_per_project"
  end
end
