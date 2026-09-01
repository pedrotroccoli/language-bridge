module Api
  module V1
    # Bearer-token JSON export for one locale, compiled the way an i18next client
    # loads it: every namespace as a nested object keyed under its name. Powers the
    # `@language-bridge/cli` type generator (pull → emit resources.d.ts).
    #
    #   GET /api/v1/projects/:project_slug/export?locale=en
    #   GET /api/v1/projects/:project_slug/export            # defaults to source locale
    #   GET /api/v1/projects/:project_slug/export?include_drafts=1
    #
    #   { "project": "main-app", "locale": "en", "is_source": true,
    #     "namespaces": { "common": { "common": { "welcome": "Welcome" } } },
    #     "available_locales": ["en", "pt-BR", "es"], "source_locale": "en" }
    #
    # Published strings are already served unauthenticated at /cdn, so any valid
    # token may read them (no scope required). Drafts are NOT public, so
    # ?include_drafts=1 additionally requires an editor-equivalent scope
    # (save_missing or admin — mirrors the web export's can_edit_translations?).
    class ExportsController < Api::BaseController
      before_action -> { require_scope!(:save_missing) }, if: :include_drafts?

      def show
        locale = resolve_locale
        return render_error(:not_found, "Locale not found") if locale.nil?

        render json: {
          project: @project.slug,
          locale: locale.code,
          is_source: locale.is_source,
          namespaces: compile(locale),
          available_locales: @project.locales.order(:code).pluck(:code),
          source_locale: @project.source_locale&.code
        }
      end

      private
        def resolve_locale
          code = params[:locale].to_s.presence
          code ? @project.locales.find_by(code: code) : @project.source_locale
        end

        # { namespace_name => nested i18next tree }, skipping namespaces with no
        # values for this locale. One query for the whole locale (grouped by
        # namespace in memory) rather than a bundle query per namespace.
        def compile(locale)
          by_namespace = translations_for(locale).group_by { |t| t.translation_key.namespace_id }

          @project.namespaces.order(:name).each_with_object({}) do |namespace, out|
            rows = by_namespace[namespace.id]
            out[namespace.name] = nest(rows) if rows.present?
          end
        end

        # Non-empty values for the locale across the project; published only unless
        # drafts were explicitly (and authorizedly) requested.
        def translations_for(locale)
          scope = @project.translations
            .where(locale: locale)
            .where.not(value: [ nil, "" ])
            .includes(:translation_key)
          include_drafts? ? scope : scope.published
        end

        # Expand dotted keys ("home.title") into nested objects, matching
        # TranslationBundle / NamespaceExport delivery shape.
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

        def include_drafts?
          ActiveModel::Type::Boolean.new.cast(params[:include_drafts])
        end
    end
  end
end
