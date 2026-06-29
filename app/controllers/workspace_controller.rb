# Global, admin-only workspace settings (rate-limit defaults). Top-level, not
# project-scoped. Per-project overrides live in Projects::SettingsController.
class WorkspaceController < ApplicationController
  before_action :require_admin

  def show
    @setting = Setting.current
    @storage_connections = StorageConnection.ordered
    @new_connection = StorageConnection.new(service: "local")
  end

  def update
    @setting = Setting.current
    if @setting.update(setting_params)
      redirect_to workspace_path, notice: "Workspace settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def setting_params
      params.expect(setting: [
        :rate_limiting_enabled,
        :missing_rate_limit, :missing_rate_period,
        :delivery_rate_limit, :delivery_rate_period,
        :upload_max_bytes,
        { upload_allowed_formats: [] }
      ])
    end
end
