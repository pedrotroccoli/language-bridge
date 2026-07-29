class Projects::ApiTokensController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_administer_project

  def create
    _record, raw = ApiToken.generate(
      project: @project,
      name:    token_params[:name].presence || "API token",
      scope:   token_params[:scope].presence || "save_missing",
      creator: current_user
    )
    # The raw token is shown exactly once, via flash, on the settings page.
    redirect_to project_settings_path(@project),
                flash: { token_created: raw, notice: "API token created — copy it now, it won't be shown again." }
  rescue ActiveRecord::RecordInvalid => e
    redirect_to project_settings_path(@project), alert: e.message
  end

  def destroy
    @project.api_tokens.find(params[:id]).update!(revoked_at: Time.current)
    redirect_to project_settings_path(@project), notice: "API token revoked."
  end

  private
    def token_params
      params.expect(api_token: %i[ name scope ])
    end
end
