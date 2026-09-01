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
end
