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
      project = namespace.project
      key = project.delivery_storage_key(namespace, locale)

      # Store the bytes already compressed (issue #95) so delivery streams them
      # as-is under Content-Encoding. nil encoding = stored uncompressed.
      encoding, body = DeliveryCompression.compress(content.to_json, Setting.current.delivery_compression)

      artifact = upsert(namespace, locale, content)
      write_blob(artifact, key, locale, body, project.storage_service_name, encoding)
      # Advance the served checksum/ETag only AFTER the blob is durably written,
      # so a failed upload never leaves the row pointing past its stored content.
      # The checksum is the hash of the *logical* JSON (compression-independent),
      # so 304s keep working across a compression-mode change.
      artifact.update!(checksum: content.etag, built_at: Time.current, content_encoding: encoding)
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
      def write_blob(artifact, key, locale, body, service_name, encoding)
        io = StringIO.new(body)

        # Reuse the blob in place only when both the key AND the routed service
        # are unchanged; otherwise (template edit or a new/changed storage
        # connection) purge and re-attach so the object moves to the right bucket.
        if artifact.file.attached? && artifact.file.key == key && artifact.file.blob.service_name == (service_name || default_service_name)
          blob = artifact.file.blob
          blob.upload(io, identify: false)
          blob.content_type = "application/json"
          blob.save!
        else
          artifact.file.purge if artifact.file.attached?
          options = { io: io, key: key, filename: "#{locale.code}.json", content_type: "application/json" }
          options[:service_name] = service_name if service_name
          artifact.file.attach(**options)
        end

        # Stamp the object's Content-Encoding so a customer CDN reading the bucket
        # directly (bypassing DeliveryController) decompresses correctly. Active
        # Storage's attach/upload don't set it; do it best-effort on S3 services.
        set_object_content_encoding(artifact.file.blob, encoding)
      end

      # Best-effort: set the stored object's Content-Encoding metadata. Only S3
      # services support it; Disk (dev/test) and anything else are skipped. Never
      # let a metadata hiccup fail the rebuild — the DeliveryController path still
      # sends the header from artifact.content_encoding regardless.
      def set_object_content_encoding(blob, encoding)
        return if encoding.nil?
        service = blob.service
        return unless service.class.name.to_s.include?("S3")

        object = service.send(:bucket).object(blob.key)
        object.copy_from(object, content_type: "application/json", content_encoding: encoding, metadata_directive: "REPLACE")
      rescue => e
        Rails.logger.warn("[delivery] could not set Content-Encoding on #{blob.key}: #{e.class}: #{e.message}")
      end

      def default_service_name
        ActiveStorage::Blob.service.name.to_s
      end

      def batched
        Current.artifact_rebuild_batch
      end
  end
end
