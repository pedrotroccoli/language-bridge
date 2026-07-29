class TranslationsController < ApplicationController
  include ProjectScoped
  include TranslationCells

  before_action :ensure_can_edit_translations

  def create
    attrs = create_params
    translation_key = @project.translation_keys.find(attrs[:translation_key_id])
    locale = @project.locales.find(attrs[:locale_id])

    @translation = translation_key.set_translation(locale: locale, value: attrs[:value], author: current_user)

    respond_with_cell(@translation, "Translation saved.")
  end

  def update
    @translation = project_translations.find(params[:id])
    @translation.update!(value: update_params[:value], author: current_user)

    respond_with_cell(@translation, "Translation saved.")
  end

  private
    def create_params
      params.expect(translation: %i[ value translation_key_id locale_id ])
    end

    def update_params
      params.expect(translation: %i[ value ])
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
