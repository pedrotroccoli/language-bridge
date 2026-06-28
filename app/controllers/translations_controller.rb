class TranslationsController < ApplicationController
  include TranslationCells

  before_action :set_project
  before_action :ensure_can_edit_translations

  def create
    attrs = create_params
    translation_key = @project.translation_keys.find(attrs[:translation_key_id])
    locale = @project.locales.find(attrs[:locale_id])

    @translation = Translation.find_or_initialize_by(translation_key: translation_key, locale: locale)
    @translation.assign_attributes(value: attrs[:value], author: current_user)
    @translation.save!

    respond_with_cell(@translation, "Translation saved.")
  end

  def update
    @translation = project_translations.find(params[:id])
    @translation.update!(value: update_params[:value], author: current_user)

    respond_with_cell(@translation, "Translation saved.")
  end

  private
    def set_project
      @project = current_user.accessible_projects.find_by!(slug: params[:project_id])
    end

    def project_translations
      Translation.joins(:translation_key).where(translation_keys: { project_id: @project.id })
    end

    def create_params
      params.expect(translation: %i[ value translation_key_id locale_id ])
    end

    def update_params
      params.expect(translation: %i[ value ])
    end

    def ensure_can_edit_translations
      head :forbidden unless current_user&.can_edit_translations?(@project)
    end

    # Replace just the cell's Turbo Frame so the update works regardless of the
    # search/pagination window the row came from. Falls back to a redirect when
    # JS/Turbo is unavailable.
    def respond_with_cell(translation, notice)
      if turbo_frame_request?
        render turbo_stream: translation_cell_streams(@project, translation)
      else
        redirect_to project_namespace_path(@project, translation.translation_key.namespace),
                    notice: notice, status: :see_other
      end
    end
end
