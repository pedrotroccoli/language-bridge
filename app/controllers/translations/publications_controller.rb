class Translations::PublicationsController < ApplicationController
  include TranslationCells

  before_action :set_project
  before_action :set_translation
  before_action :ensure_can_edit_translations

  def create
    @translation.create_publication! unless @translation.publication
    respond_with_cell("Translation published.")
  end

  def destroy
    @translation.publication&.destroy!
    respond_with_cell("Translation unpublished.")
  end

  private
    def set_project
      @project = current_user.accessible_projects.find_by!(slug: params[:project_id])
    end

    def set_translation
      @translation = Translation.joins(:translation_key)
                                .where(translation_keys: { project_id: @project.id })
                                .find(params[:translation_id])
    end

    def ensure_can_edit_translations
      head :forbidden unless current_user&.can_edit_translations?(@project)
    end

    def respond_with_cell(notice)
      @translation.reload
      if turbo_frame_request?
        render turbo_stream: translation_cell_streams(@project, @translation)
      else
        redirect_to project_namespace_path(@project, @translation.translation_key.namespace),
                    notice: notice, status: :see_other
      end
    end
end
