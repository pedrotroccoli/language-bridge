# Downloads a whole project's translations. Mirrors Namespaces::ExportsController:
#   * default ("data") — clean, metadata-free files for every namespace × locale,
#     laid out as "<locale>/<namespace>.<ext>" in a ZIP (i18next/locize-ready).
#   * mode=backup — full-fidelity project Snapshot (version + published flags) in
#     JSON / CSV / XLIFF, for our own backup & restore.
class Projects::ExportsController < ApplicationController
  include ProjectScoped

  def show
    params[:mode] == "backup" ? send_backup : send_data_export
  end

  private
    def send_data_export
      format = params[:as].to_s.presence_in(ProjectExport::FORMATS) || "json"
      file = ProjectExport.new(@project).download(format)
      send_data file.body, filename: file.filename, type: file.content_type
    rescue NamespaceExport::Error => e
      redirect_to project_path(@project), alert: e.message, status: :see_other
    end

    def send_backup
      format = params[:as].to_s.presence_in(Snapshot::FORMATS) || "json"
      body, content_type, ext = Snapshot.dump(TranslationSnapshot.build(@project), format: format)
      send_data body, filename: "#{@project.slug}.#{ext}", type: content_type
    end
end
