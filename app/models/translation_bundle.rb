# Compiles the published translations of a single (namespace, locale) pair into
# the nested JSON shape an i18n client (e.g. i18next) consumes. This is the
# inverse of TranslationImport#flatten: dotted keys ("home.title") expand back
# into nested objects. Only published translations with a value are included.
#
# The same builder backs both delivery modes: DeliveryController renders #to_h
# live, and a future materialized artifact would persist #to_json. #etag gives a
# stable content fingerprint for HTTP caching and change detection.
class TranslationBundle
  def initialize(namespace:, locale:)
    @namespace = namespace
    @locale = locale
  end

  def to_h
    published.each_with_object({}) do |translation, tree|
      insert(tree, translation.translation_key.key.split("."), translation.value)
    end
  end

  def to_json(*)
    JSON.generate(to_h)
  end

  def etag
    Digest::SHA256.hexdigest(to_json)
  end

  private
    def published
      Translation.published
        .where(locale: @locale)
        .joins(:translation_key)
        .where(translation_keys: { namespace_id: @namespace.id })
        .where.not(value: [ nil, "" ])
        .includes(:translation_key)
    end

    def insert(tree, segments, value)
      leaf = segments.pop
      node = segments.reduce(tree) do |hash, segment|
        hash[segment] = {} unless hash[segment].is_a?(Hash)
        hash[segment]
      end
      node[leaf] = value
    end
end
