# Compiles one locale across every namespace of a project into the i18next-shaped
# JSON the CLI type generator consumes: { namespace_name => nested tree }. One
# query for the whole locale (grouped by namespace), unlike the per-namespace
# TranslationBundle. Published only unless include_drafts is set.
class LocaleBundle
  def initialize(project, locale, include_drafts: false)
    @project = project
    @locale = locale
    @include_drafts = include_drafts
  end

  # Skips namespaces with no values for the locale so the client never types
  # empty branches.
  def to_h
    grouped = translations.group_by { |translation| translation.translation_key.namespace_id }

    @project.namespaces.order(:name).each_with_object({}) do |namespace, out|
      rows = grouped[namespace.id]
      out[namespace.name] = TranslationTree.nest(rows) if rows.present?
    end
  end

  private
    def translations
      scope = @project.translations
        .where(locale: @locale)
        .where.not(value: [ nil, "" ])
        .includes(:translation_key)
      @include_drafts ? scope : scope.published
    end
end
