class Translations::ReviewsController < ApplicationController
  include ProjectScoped
  include TranslationCells

  before_action :set_translation
  before_action :ensure_can_edit_translations

  def create
    @translation.request_review(by: current_user)
    respond_with_cell("Marked for review.")
  end

  def destroy
    @translation.review&.destroy!
    respond_with_cell("Review request cleared.")
  end

  private
    def set_translation
      @translation = project_translations.find(params[:translation_id])
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
