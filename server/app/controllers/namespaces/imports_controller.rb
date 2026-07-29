# Imports a translations file (JSON / CSV / XLIFF) for a locale into a namespace,
# honoring the project's allowed-format and max-size upload rules.
class Namespaces::ImportsController < ApplicationController
  include ProjectScoped

  before_action :set_namespace
  before_action :ensure_can_administer_project

  def create
    locale = @project.locales.find_by(id: params[:locale_id])
    return redirect_back("Select a locale to import into.") if locale.nil?

    file = params[:file]
    return redirect_back("Choose a file to import.") if file.blank?

    if file.size > @project.effective_upload_max_bytes
      return redirect_back("File is too large (max #{helpers.number_to_human_size(@project.effective_upload_max_bytes)}).")
    end

    format = TranslationImport.format_from_filename(file.original_filename)
    unless @project.effective_upload_allowed_formats.include?(format)
      return redirect_back("#{format.upcase} files aren't allowed for this project.")
    end

    result = TranslationImport.new(namespace: @namespace, locale: locale, author: current_user, format: format).import(file.read)
    redirect_to project_namespace_path(@project, @namespace), notice: result.summary(locale), status: :see_other
  rescue TranslationImport::Error => e
    redirect_back("Import failed: #{e.message}")
  end

  private
    def set_namespace
      @namespace = @project.namespaces.find_by!(name: params[:namespace_id])
    end

    def redirect_back(alert)
      redirect_to project_namespace_path(@project, @namespace), alert: alert, status: :see_other
    end
end
