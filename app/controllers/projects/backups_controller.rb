class Projects::BackupsController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_administer_project

  def index
    @backups = @project.backups.recent.limit(30)
  end

  # Back up now — runs synchronously so the new snapshot is visible immediately.
  def create
    BackupProjectJob.perform_now(@project, source: "manual")
    redirect_to project_backups_path(@project), notice: "Backup created."
  end

  def destroy
    @project.backups.find(params[:id]).destroy
    redirect_to project_backups_path(@project), notice: "Backup deleted."
  end
end
