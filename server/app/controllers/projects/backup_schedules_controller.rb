# A project's automatic-backup schedule (frequency, retention, drafts).
class Projects::BackupSchedulesController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_administer_project

  def update
    if @project.update(schedule_params)
      redirect_to project_backups_path(@project), notice: "Backup schedule saved."
    else
      redirect_to project_backups_path(@project), alert: @project.errors.full_messages.to_sentence
    end
  end

  private
    def schedule_params
      params.expect(project: %i[
        backups_enabled backup_frequency backup_retention backup_include_drafts
        backup_format backup_time_of_day
      ])
    end
end
