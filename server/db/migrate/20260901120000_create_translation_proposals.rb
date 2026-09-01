class CreateTranslationProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :translation_proposals, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :project_id, null: false
      t.uuid :namespace_id, null: false
      t.uuid :locale_id, null: false
      t.uuid :author_id, null: false
      t.string :key, null: false
      t.text :value, null: false
      # A client-supplied grouping label (git branch or AI chat) so parallel work
      # streams stay separate. Empty string when unscoped, never NULL, so the
      # unique index below still dedupes.
      t.string :session, null: false, default: ""
      t.timestamps
    end

    add_index :translation_proposals, :project_id
    add_index :translation_proposals, :author_id
    # One open proposal per (namespace, key, locale, session): a re-push from the
    # same session overwrites its pending value, while a different branch/chat
    # keeps its own proposal for the same key. The key is stored as a string so a
    # brand-new key never appears in the project until accepted.
    add_index :translation_proposals, [ :namespace_id, :key, :locale_id, :session ],
      unique: true, name: "index_translation_proposals_on_namespace_key_locale_session"

    add_foreign_key :translation_proposals, :projects
    add_foreign_key :translation_proposals, :namespaces
    add_foreign_key :translation_proposals, :locales
    add_foreign_key :translation_proposals, :users, column: :author_id
  end
end
