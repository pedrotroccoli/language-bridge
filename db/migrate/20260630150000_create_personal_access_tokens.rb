class CreatePersonalAccessTokens < ActiveRecord::Migration[8.1]
  def change
    # Per-user bearer token (lb_pat_…) for the personal API / CLI. One per user;
    # only the SHA-256 digest is stored. Regenerating replaces the row.
    create_table :personal_access_tokens, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :personal_access_tokens, :token_digest, unique: true
  end
end
