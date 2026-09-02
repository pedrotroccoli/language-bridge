# The playground delivery file: published translations plus every draft for one
# (namespace, locale), written to the project's connected storage under
# playground/. A dev environment points its i18n loadPath here to see work in
# progress; production points at the published artifact paths instead.
#
# Like Translation::SessionArtifact these are plain objects overwritten in place
# (no AR row, no blob). Rebuilt whenever any value changes — publish state alone
# doesn't matter, since the playground includes drafts and published alike.
# Rebuilds are coalesced via .batch so a bulk push recompiles each affected
# (namespace, locale) once.
class Translation::PlaygroundArtifact
  class << self
    def touch_for(translation)
      pair = [ translation.translation_key.namespace_id, translation.locale_id ]

      if (batched = Current.playground_rebuild_batch)
        batched << pair
      else
        rebuild(*pair)
      end
    end

    def batch
      Current.playground_rebuild_batch = Set.new
      yield
    ensure
      pairs = Current.playground_rebuild_batch
      Current.playground_rebuild_batch = nil
      pairs&.each { |namespace_id, locale_id| rebuild(namespace_id, locale_id) }
    end

    def rebuild(namespace_id, locale_id)
      namespace = Namespace.find(namespace_id)
      locale = Locale.find(locale_id)
      materialize(namespace: namespace, locale: locale)
    rescue ActiveRecord::RecordNotFound
      # Deleted concurrently (e.g. mid cascade); nothing left to materialize.
      nil
    end

    # Returns the storage key written.
    def materialize(namespace:, locale:)
      project = namespace.project
      bundle = TranslationBundle.new(namespace: namespace, locale: locale, include_drafts: true)
      key = storage_key(project, namespace, locale)

      project.storage_service.upload(key, StringIO.new(bundle.to_json), content_type: "application/json")
      key
    end

    def storage_key(project, namespace, locale)
      project.storage_key("playground", project.delivery_key_for(namespace, locale))
    end
  end
end
