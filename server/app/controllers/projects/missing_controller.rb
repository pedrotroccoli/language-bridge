class Projects::MissingController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_edit_translations, only: :destroy

  def index
    @reports = @project.missing_key_reports.recent
  end

  # Ignore (dismiss) a reported key.
  def destroy
    @project.missing_key_reports.find(params[:id]).destroy
    redirect_to project_missing_index_path(@project), notice: "Report ignored."
  end
end
