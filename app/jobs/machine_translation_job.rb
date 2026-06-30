# Bulk prefill: fill a locale's empty keys with machine translations of the
# project's source values, as drafts. Used when a locale is added with the
# "pre-fill" option. Idempotent — keys that already have a value are skipped.
class MachineTranslationJob < ApplicationJob
  queue_as :default

  def perform(locale)
    project = locale.project
    source = project.source_locale
    return if source.nil? || source.id == locale.id

    sources = source.translations.where.not(value: [ nil, "" ]).includes(:translation_key)

    # Preload the target locale's already-filled keys in one query so the loop
    # doesn't issue a find_by per source key (N+1).
    already_filled = project.translations
                            .where(locale_id: locale.id).where.not(value: [ nil, "" ])
                            .pluck(:translation_key_id).to_set

    sources.find_each do |src|
      next if already_filled.include?(src.translation_key_id)

      translated = MachineTranslation.translate(src.value, from: source.code, to: locale.code)
      src.translation_key.set_translation(locale: locale, value: translated, author: nil)
    end
  end
end
