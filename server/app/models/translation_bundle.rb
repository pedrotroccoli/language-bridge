# Compiles the translations of a single (namespace, locale) pair into the
# nested JSON shape an i18n client (e.g. i18next) consumes. This is the inverse
# of TranslationImport#flatten: dotted keys ("home.title") expand back into
# nested objects. Only published translations are included — unless a `session`
# is given (adds that push session's drafts) or `include_drafts:` is set (adds
# every draft — the playground). A key's row is either published or a draft, so
# these are unions, not overlays.
#
# The same builder backs both delivery modes: DeliveryController renders #to_h
# live, Translation::Artifact persists #to_json, and Translation::SessionArtifact
# persists the session variant. #etag gives a stable content fingerprint for
# HTTP caching and change detection.
class TranslationBundle
  def initialize(namespace:, locale:, session: nil, include_drafts: false)
    @namespace = namespace
    @locale = locale
    @session = session
    @include_drafts = include_drafts
  end

  def to_h
    TranslationTree.nest(rows)
  end

  def to_json(*)
    JSON.generate(to_h)
  end

  def etag
    Digest::SHA256.hexdigest(to_json)
  end

  private
    def rows
      scope = Translation
        .where(locale: @locale)
        .joins(:translation_key)
        .where(translation_keys: { namespace_id: @namespace.id })
        .where.not(value: [ nil, "" ])
        .includes(:translation_key)

      if @include_drafts
        scope # every row with a value: published + all drafts
      elsif @session
        scope.left_joins(:publication)
          .where("translation_publications.id IS NOT NULL OR translations.session = ?", @session)
      else
        scope.joins(:publication)
      end
    end
end
