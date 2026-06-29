class Projects::BackupsController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_administer_project

  def index
    @backups = @project.backups.recent.limit(30)
  end

  # Back up now — runs synchronously so the new snapshot is visible immediately.
  # Paused until a storage connection is configured (mirrors the UI gate).
  def create
    unless @project.effective_storage_connection&.usable?
      return redirect_to project_backups_path(@project), alert: "Connect a storage bucket before backing up."
    end

    BackupProjectJob.perform_now(@project, source: "manual")
    redirect_to project_backups_path(@project), notice: "Backup created."
  end

  def destroy
    @project.backups.find(params[:id]).destroy
    redirect_to project_backups_path(@project), notice: "Backup deleted."
  end
end
