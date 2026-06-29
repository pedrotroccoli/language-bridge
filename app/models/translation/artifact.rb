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
      key = namespace.project.delivery_key_for(namespace, locale)

      artifact = upsert(namespace, locale, content)
      write_blob(artifact, key, locale, content.to_json)
      # Advance the served checksum/ETag only AFTER the blob is durably written,
      # so a failed upload never leaves the row pointing past its stored content.
      artifact.update!(checksum: content.etag, built_at: Time.current)
      artifact
    rescue ActiveRecord::RecordNotFound, ActiveRecord::InvalidForeignKey
      # The namespace or locale was deleted concurrently (e.g. mid cascade);
      # there's nothing left to materialize for this pair.
      nil
    end

    private
      def upsert(namespace, locale, content)
        artifact = find_or_initialize_by(namespace: namespace, locale: locale)
        artifact.project = namespace.project
        # New rows need a checksum (NOT NULL); existing rows keep their current
        # one until the blob is durably re-written (see rebuild).
        artifact.checksum ||= content.etag
        artifact.built_at ||= Time.current
        artifact.save!
        artifact
      rescue ActiveRecord::RecordNotUnique
        # A concurrent rebuild inserted the row first; retry so find_or_initialize
        # takes the update path instead of a colliding insert.
        retry
      end

      # Materialize the JSON at a deterministic key (issue #77). When the key is
      # unchanged (a content edit), overwrite the existing blob in place — reusing
      # the same key without the attach+purge churn that would otherwise delete the
      # object we just wrote. When the key changed (template edit), purge the old
      # blob and attach a fresh one at the new path.
      def write_blob(artifact, key, locale, json)
        io = StringIO.new(json)

        if artifact.file.attached? && artifact.file.key == key
          blob = artifact.file.blob
          blob.upload(io, identify: false)
          blob.content_type = "application/json"
          blob.save!
        else
          artifact.file.purge if artifact.file.attached?
          artifact.file.attach(io: io, key: key, filename: "#{locale.code}.json", content_type: "application/json")
        end
      end

      def batched
        Current.artifact_rebuild_batch
      end
  end
end
