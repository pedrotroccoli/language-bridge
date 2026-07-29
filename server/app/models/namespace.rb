class Namespace < ApplicationRecord
  NAME_FORMAT = /\A[a-z0-9][a-z0-9_\-\.]*\z/
  private_constant :NAME_FORMAT

  belongs_to :project, counter_cache: true

  has_many :translation_keys, dependent: :destroy
  has_many :translation_artifacts, class_name: "Translation::Artifact", dependent: :destroy

  validates :name, presence: true,
                   format: { with: NAME_FORMAT, message: "must be lowercase alnum with -, _, . (no leading separator)" },
                   uniqueness: { scope: :project_id }

  scope :alphabetically, -> { order(name: :asc) }

  def to_param = name

  # All translations under this namespace (across every key).
  def translations
    Translation.joins(:translation_key).where(translation_keys: { namespace_id: id })
  end

  def draft_count
    Translation.drafts_in_namespace(self).count
  end

  # Editor sidebar aggregates in a single grouped query:
  #   :stats    — translated/drafts/missing/total + changed_7/changed_30 counts
  #   :coverage — locale_id => percent of keys translated for that locale
  def editor_overview(locales, total_keys: translation_keys.count)
    scoped = translations
    filled_by_locale = scoped.where.not(value: [ nil, "" ]).group(:locale_id).count
    filled_total = filled_by_locale.values.sum
    slots = total_keys * locales.size

    coverage = locales.each_with_object({}) do |locale, map|
      map[locale.id] = total_keys.zero? ? 0 : ((filled_by_locale[locale.id].to_i.to_f / total_keys) * 100).round.clamp(0, 100)
    end

    stats = {
      translated: scoped.published.count,
      drafts: draft_count,
      review: scoped.under_review.count,
      missing: [ slots - filled_total, 0 ].max,
      total: slots,
      changed_7: scoped.where("translations.updated_at >= ?", 7.days.ago).count,
      changed_30: scoped.where("translations.updated_at >= ?", 30.days.ago).count
    }

    { stats:, coverage: }
  end

  # Namespace-wide QA tally against the project's source locale:
  #   :warnings — translations with a placeholder/length warning
  #   :fuzzy    — translations stale relative to a newer source value
  # Loads the source-locale values once (one per key), then streams the other
  # translations in batches so the whole namespace isn't held in memory.
  def qa_overview(source_locale)
    return { warnings: 0, fuzzy: 0 } if source_locale.nil?

    sources = translations.where(locale_id: source_locale.id)
                          .select(:translation_key_id, :value, :updated_at)
                          .index_by(&:translation_key_id)
    warnings = fuzzy = 0

    translations.where.not(locale_id: source_locale.id)
                .select(:id, :translation_key_id, :value, :updated_at)
                .find_each do |translation|
      source = sources[translation.translation_key_id]
      warnings += 1 if Translation::Qa.warnings(translation, source).any?
      fuzzy += 1 if Translation::Qa.fuzzy?(translation, source)
    end

    { warnings:, fuzzy: }
  end
end
