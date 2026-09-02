class GranularTokenScopes < ActiveRecord::Migration[8.1]
  # No tokens exist in production yet, so the single-scope columns are replaced
  # outright with a capability set (string array) rather than data-migrated.
  def up
    add_column :personal_access_tokens, :scopes, :string, array: true, null: false, default: []
    remove_column :personal_access_tokens, :scope

    add_column :api_tokens, :scopes, :string, array: true, null: false, default: []
    remove_column :api_tokens, :scope

    add_column :cli_auth_codes, :scopes, :string, array: true, null: false, default: []
    remove_column :cli_auth_codes, :scope
  end

  def down
    add_column :personal_access_tokens, :scope, :string, null: false, default: "read_only"
    remove_column :personal_access_tokens, :scopes

    add_column :api_tokens, :scope, :string
    remove_column :api_tokens, :scopes

    add_column :cli_auth_codes, :scope, :string, null: false, default: "save_missing"
    remove_column :cli_auth_codes, :scopes
  end
end
