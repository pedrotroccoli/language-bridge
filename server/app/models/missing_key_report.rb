# A runtime "missing key" reported by an i18next client via saveMissing. Rather
# than auto-creating keys (which would pollute the keyspace), reports land in a
# per-project triage inbox: each accumulates hit counts and the locales that
# requested it. From the Missing tab an editor either promotes a report to a real
# key or ignores it.
class MissingKeyReport < ApplicationRecord
  belongs_to :project

  validates :namespace, presence: true, length: { maximum: 255 }
  validates :key, presence: true, length: { maximum: 1024 }

  scope :recent, -> { order(last_reported_at: :desc) }

  # Record one runtime miss: bump the hit counter, union in the locale, stamp the
  # time. Upsert keyed on (project, namespace, key); retries on a concurrent
  # insert. The counter bump + locale union run as a single atomic SQL UPDATE so
  # concurrent reports of the same key can't lose increments (read-modify-write
  # would).
  def self.record!(project:, namespace:, key:, locale:)
    report = find_or_create_by!(project: project, namespace: namespace, key: key) do |r|
      r.first_reported_at = Time.current
    end

    where(id: report.id).update_all(sanitize_sql_array([
      "hits = hits + 1, last_reported_at = ?, " \
      "locales = CASE WHEN locales @> ?::jsonb THEN locales ELSE locales || ?::jsonb END",
      Time.current, [ locale ].to_json, [ locale ].to_json
    ]))
    report
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  # Promote to a real key: create the namespace, the reported locales, the key,
  # and an empty (missing) translation per locale, then drop the report.
  def promote!(author: Current.user)
    translation_key = nil
    transaction do
      namespace_record = project.namespaces.find_or_create_by!(name: namespace)
      translation_key = project.translation_keys.find_or_create_by!(namespace: namespace_record, key: key)
      locales.each do |code|
        locale = project.locales.find_or_create_by!(code: code)
        translation_key.set_translation(locale: locale, value: nil, author: author) unless translation_key.translations.exists?(locale: locale)
      end
      destroy!
    end
    translation_key
  end
end
