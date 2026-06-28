# A materialized delivery file: the compiled JSON for one (namespace, locale)
# stored as an Active Storage attachment. Rebuilt synchronously whenever the
# published content of that pair changes (publish, unpublish, or an edit that
# discards a publication). DeliveryController serves the attached blob when
# present, falling back to compiling live.
#
# Rebuilds are coalesced via .batch so a bulk "publish all" recompiles each
# affected (namespace, locale) once instead of once per translation.
class Translation::Artifact < ApplicationRecord
  belongs_to :project
  belongs_to :namespace
  belongs_to :locale

  has_one_attached :file

  validates :namespace_id, uniqueness: { scope: :locale_id }

  class << self
    # Record a content change for a translation's (namespace, locale). Rebuilds
    # immediately, unless inside a .batch block, where pairs are deduped and
    # rebuilt once on exit.
    def touch_for(translation)
      pair = [ translation.translation_key.namespace_id, translation.locale_id ]

      if batched
        batched << pair
      else
        rebuild(*pair)
      end
    end

    def batch
      Current.artifact_rebuild_batch = Set.new
      yield
    ensure
      # Rebuild in ensure so partially-applied work (e.g. a "publish all" that
      # raises midway) still materializes the pairs already touched.
      pairs = Current.artifact_rebuild_batch
      Current.artifact_rebuild_batch = nil
      pairs&.each { |namespace_id, locale_id| rebuild(namespace_id, locale_id) }
    end

    # Backfill: materialize every (namespace, locale) that currently has
    # published content. Idempotent — safe to re-run.
    def rebuild_all
      pairs = Translation.published.joins(:translation_key)
        .distinct.pluck("translation_keys.namespace_id", :locale_id)
      pairs.each { |namespace_id, locale_id| rebuild(namespace_id, locale_id) }
      pairs.size
    end

    def rebuild(namespace_id, locale_id)
      namespace = Namespace.find(namespace_id)
      locale = Locale.find(locale_id)
      content = TranslationBundle.new(namespace: namespace, locale: locale)

      artifact = find_or_initialize_by(namespace: namespace, locale: locale)
      artifact.update!(project: namespace.project, checksum: content.etag, built_at: Time.current)
      artifact.file.attach(
        io: StringIO.new(content.to_json),
        filename: "#{locale.code}.json",
        content_type: "application/json"
      )
      artifact
    rescue ActiveRecord::RecordNotUnique
      # A concurrent rebuild inserted the row first; retry so find_or_initialize
      # takes the update path instead of a colliding insert.
      retry
    end

    private
      def batched
        Current.artifact_rebuild_batch
      end
  end
end
