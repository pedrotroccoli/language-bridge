# Materializes a push session's playground JSON in the project's connected
# storage: the published bundle overlaid with that session's drafts, written at
# a deterministic key under sessions/<session>/. A frontend can point its i18n
# loadPath at the path to preview the session before anything is published.
#
# Unlike Translation::Artifact these are ephemeral previews — no AR row, no
# Active Storage blob; each push overwrites the same object in place.
class Translation::SessionArtifact
  class << self
    # Write one (namespace, locale) preview. Returns the storage key written.
    def materialize(namespace:, locale:, session:)
      project = namespace.project
      bundle = TranslationBundle.new(namespace: namespace, locale: locale, session: session)
      key = storage_key(project, namespace, locale, session)

      project.storage_service.upload(key, StringIO.new(bundle.to_json), content_type: "application/json")
      # Read straight from the bucket/CDN, so keep the cache tiny — long enough
      # to shave repeat reads, short enough that an updated preview shows up.
      stamp_short_cache(project.storage_service, key)
      key
    end

    # Every (namespace, locale) pair the session has drafts for, materialized.
    # Returns the keys written.
    def materialize_session(project, session)
      return [] if session.blank?

      pairs = project.translations.drafts_in_session(session)
        .joins(:translation_key)
        .distinct.pluck("translation_keys.namespace_id", :locale_id)

      pairs.map do |namespace_id, locale_id|
        materialize(
          namespace: project.namespaces.find(namespace_id),
          locale: project.locales.find(locale_id),
          session: session
        )
      end
    end

    def storage_key(project, namespace, locale, session)
      project.storage_key("sessions", slug(session), project.delivery_key_for(namespace, locale))
    end

    private
      # Active Storage's #upload takes no per-object Cache-Control, so re-put the
      # object with a short one via a self-copy. Best-effort, S3 only (unwrapping
      # a mirror to its primary); a failure just leaves the bucket/CDN default.
      def stamp_short_cache(service, key)
        service = service.primary if service.respond_to?(:primary)
        return unless service.is_a?(ActiveStorage::Service::S3Service)

        object = service.bucket.object(key)
        object.copy_from(object, content_type: "application/json", cache_control: "public, max-age=15", metadata_directive: "REPLACE")
      rescue => e
        Rails.logger.warn("[session] could not set Cache-Control on #{key}: #{e.class}: #{e.message}")
      end

      # Sessions are user input (git branch, chat id); keep only path-safe
      # characters and drop dot-only segments so the object key can never
      # traverse out of the storage root (the Disk service joins keys into
      # filesystem paths).
      def slug(session)
        session.gsub(%r{[^A-Za-z0-9/_\-.]}, "-")
          .split("/")
          .reject { |part| part.blank? || part.match?(/\A\.+\z/) }
          .join("/")
      end
  end
end
