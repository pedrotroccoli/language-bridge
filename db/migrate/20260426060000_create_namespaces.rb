class CreateNamespaces < ActiveRecord::Migration[8.1]
  def change
    create_table :namespaces, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.integer :translation_keys_count, null: false, default: 0

      t.timestamps
    end

    add_index :namespaces, [ :project_id, :name ], unique: true
  end
end
