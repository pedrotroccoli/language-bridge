class AddScopeToTokens < ActiveRecord::Migration[8.1]
  def change
    # Per-token scope (was derived from the user's role). Least-privilege default:
    # a token can only read until explicitly granted more.
    add_column :personal_access_tokens, :scope, :string, null: false, default: "read_only"
    # `lb login` mints draft-capable tokens (no admin) by default.
    add_column :cli_auth_codes, :scope, :string, null: false, default: "save_missing"
  end
end
