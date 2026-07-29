module TranslationCells
  extend ActiveSupport::Concern

  private
    # A cell action (save value, publish, unpublish) replaces both the cell's
    # Turbo Frame and the namespace's "Publish all" button, so the draft count /
    # disabled state stays in sync without a full page reload.
    def translation_cell_streams(project, translation)
      namespace = translation.translation_key.namespace
      [
        turbo_stream.replace(
          helpers.dom_id(translation.translation_key, "locale_#{translation.locale_id}"),
          method: :morph,
          partial: "translations/cell",
          locals: {
            project: project,
            translation_key: translation.translation_key,
            locale: translation.locale,
            translation: translation
          }
        ),
        turbo_stream.replace(
          "publish_all",
          method: :morph,
          partial: "namespaces/publish_all",
          locals: {
            project: project,
            namespace: namespace,
            draft_count: Translation.drafts_in_namespace(namespace).count,
            editable: true,
            keys_present: true
          }
        )
      ]
    end
end
