class ReplaceProposalsWithSessionDrafts < ActiveRecord::Migration[8.1]
  def up
    # Proposals are gone: a CLI push now writes real draft translations tagged
    # with the session that produced them, so they show up in the editor as
    # normal Unpublished rows and can be reviewed/published in place.
    add_column :translations, :session, :string
    add_index :translations, :session

    drop_table :translation_proposals
  end

  def down
    remove_column :translations, :session

    create_table :translation_proposals, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :project_id, null: false
      t.uuid :namespace_id, null: false
      t.uuid :locale_id, null: false
      t.uuid :author_id, null: false
      t.string :key, null: false
      t.text :value, null: false
      t.string :session, null: false, default: ""
      t.timestamps
    end
    add_index :translation_proposals, :project_id
    add_index :translation_proposals, :author_id
    add_index :translation_proposals, [ :namespace_id, :key, :locale_id, :session ],
      unique: true, name: "index_translation_proposals_on_namespace_key_locale_session"
    add_foreign_key :translation_proposals, :projects
    add_foreign_key :translation_proposals, :namespaces
    add_foreign_key :translation_proposals, :locales
    add_foreign_key :translation_proposals, :users, column: :author_id
  end
end
