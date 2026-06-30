# Per-cell "Auto-translate": fill one (key, locale) cell with a machine
# translation of the source-locale value, as a draft. Never publishes.
class Translations::MachineTranslationsController < ApplicationController
  include ProjectScoped
  include TranslationCells

  before_action :ensure_can_edit_translations

  def create
    key = @project.translation_keys.find(params[:translation_key_id])
    locale = @project.locales.find(params[:locale_id])
    source = @project.source_locale

    return head(:unprocessable_entity) if source.nil? || source.id == locale.id

    source_value = key.translations.find_by(locale_id: source.id)&.value
    return head(:unprocessable_entity) if source_value.blank?

    translated = MachineTranslation.translate(source_value, from: source.code, to: locale.code)
    @translation = key.set_translation(locale: locale, value: translated, author: current_user)
    respond_with_cell("Draft translated from #{source.code}.")
  end

  private
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
