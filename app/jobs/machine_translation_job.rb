# Bulk prefill: fill a locale's empty keys with machine translations of the
# project's source values, as drafts. Used when a locale is added with the
# "pre-fill" option. Idempotent — keys that already have a value are skipped.
class MachineTranslationJob < ApplicationJob
  queue_as :default

  def perform(locale)
    project = locale.project
    source = project.source_locale
    return if source.nil? || source.id == locale.id

    source.translations.where.not(value: [ nil, "" ]).includes(:translation_key).find_each do |src|
      key = src.translation_key
      next if key.translations.find_by(locale_id: locale.id)&.value.present?

      translated = MachineTranslation.translate(src.value, from: source.code, to: locale.code)
      key.set_translation(locale: locale, value: translated, author: nil)
    end
  end
end
