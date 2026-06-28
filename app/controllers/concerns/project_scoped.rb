# Shared scoping + authorization for controllers nested under a project.
module ProjectScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_project
  end

  private
    def set_project
      @project = current_user.accessible_projects.find_by!(slug: params[:project_id])
    end

    def project_translations
      Translation.joins(:translation_key).where(translation_keys: { project_id: @project.id })
    end

    def ensure_can_administer_project
      head :forbidden unless current_user&.can_administer_project?(@project)
    end

    def ensure_can_edit_translations
      head :forbidden unless current_user&.can_edit_translations?(@project)
    end
end
