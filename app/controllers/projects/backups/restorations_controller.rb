# Restore a project's translations from one of its backups.
class Projects::Backups::RestorationsController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_administer_project

  def create
    backup = @project.backups.find(params[:backup_id])
    raw = backup.file.download

    if backup.checksum.present? && Digest::SHA256.hexdigest(raw) != backup.checksum
      return redirect_to project_backups_path(@project), alert: "Backup integrity check failed — the snapshot may be corrupted."
    end

    count = TranslationSnapshot.restore(@project, JSON.parse(raw))
    redirect_to project_backups_path(@project), notice: "Restored #{count} #{"translation".pluralize(count)} from backup."
  rescue JSON::ParserError, TranslationSnapshot::FormatError => e
    redirect_to project_backups_path(@project), alert: "Could not restore backup: #{e.message}"
  end
end
