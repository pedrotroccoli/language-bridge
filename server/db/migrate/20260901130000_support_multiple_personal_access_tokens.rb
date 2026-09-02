class SupportMultiplePersonalAccessTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :personal_access_tokens, :name, :string, null: false, default: ""

    # Drop the one-per-user constraint: a user may now hold several named tokens
    # (one per machine via `lb login`), capped by Setting#cli_token_limit.
    remove_index :personal_access_tokens, column: :user_id, unique: true,
      name: "index_personal_access_tokens_on_user_id"
    add_index :personal_access_tokens, :user_id, name: "index_personal_access_tokens_on_user_id"

    # Workspace-wide cap on personal access tokens per user (admin-relaxable).
    add_column :settings, :cli_token_limit, :integer, null: false, default: 3
  end
end
