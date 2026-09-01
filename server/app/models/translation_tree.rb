# Expands dotted keys ("home.title") into the nested i18next hash an i18n client
# consumes. Shared nesting for TranslationBundle, LocaleBundle and NamespaceExport.
module TranslationTree
  module_function

  # Nest a set of Translation records by their dotted key.
  def nest(translations)
    translations.each_with_object({}) do |translation, tree|
      insert(tree, translation.translation_key.key.split("."), translation.value)
    end
  end

  def insert(tree, segments, value)
    leaf = segments.pop
    node = segments.reduce(tree) do |hash, segment|
      hash[segment] = {} unless hash[segment].is_a?(Hash)
      hash[segment]
    end
    node[leaf] = value
  end

  # Inverse of #nest: collapse a nested hash back to { "dotted.key" => value },
  # stringifying leaves and skipping blank ones. The push/import counterpart.
  def flatten(object, prefix = nil, out = {})
    object.each do |key, value|
      path = prefix ? "#{prefix}.#{key}" : key.to_s
      if value.is_a?(Hash)
        flatten(value, path, out)
      elsif value.present?
        out[path] = value.to_s
      end
    end
    out
  end
end
