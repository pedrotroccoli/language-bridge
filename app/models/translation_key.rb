class TranslationKey < ApplicationRecord
  include Eventable

  belongs_to :project, counter_cache: true
  belongs_to :namespace, counter_cache: true

  has_many :translations, dependent: :destroy

  validates :key, presence: true, uniqueness: { scope: [ :project_id, :namespace_id ] }

  scope :with_translations, ->(locale) { includes(:translations).where(translations: { locale: }) }

  # Match keys whose name OR any translation value contains the query, ranking
  # name matches ahead of value-only matches.
  def self.search(query)
    like = "%#{sanitize_sql_like(query)}%"
    matched = left_joins(:translations)
                .where("translation_keys.key ILIKE :q OR translations.value ILIKE :q", q: like)
                .select("translation_keys.id").distinct
    where(id: matched).reorder(
      Arel.sql(sanitize_sql_array([ "CASE WHEN translation_keys.key ILIKE ? THEN 0 ELSE 1 END", like ])), :key
    )
  end

  # Upsert the translation for a locale (creates missing keys' rows, overwrites
  # existing — snapshotting a Version and dropping any publication via the
  # Translation callbacks).
  def set_translation(locale:, value:, author: Current.user)
    translations.find_or_initialize_by(locale: locale).tap do |translation|
      translation.update!(value: value, author: author)
    end
  end
end
