class AddRateLimitOverridesToProjects < ActiveRecord::Migration[8.1]
  def change
    # Nullable per-project overrides — NULL means "inherit the global Setting".
    add_column :projects, :missing_rate_limit,  :integer
    add_column :projects, :delivery_rate_limit, :integer
  end
end
