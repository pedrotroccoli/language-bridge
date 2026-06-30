class AddAllowedOriginsToSettings < ActiveRecord::Migration[8.1]
  def change
    # Origins permitted to call the private API (/api/*) cross-origin. Managed
    # from the Workspace settings panel instead of an env var so self-hosters can
    # change it without a redeploy. Empty (the default) rejects all cross-origin
    # API requests; the public delivery endpoint (/cdn/*) is always open.
    add_column :settings, :allowed_origins, :string, array: true, null: false, default: []
  end
end
