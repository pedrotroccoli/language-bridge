class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :locales_count, null: false, default: 0
      t.integer :namespaces_count, null: false, default: 0
      t.integer :translation_keys_count, null: false, default: 0

      t.timestamps
    end

    add_index :projects, :slug, unique: true
  end
end
