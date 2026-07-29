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
    # Any valid token reads — reading published strings is the lowest privilege, so
    # we intentionally do NOT `require_scope!` (which only knows save_missing/admin
    # and would reject read-only PATs). By default only published values are
    # returned (matching live delivery); ?include_drafts=1 includes drafts.
    class ExportsController < Api::BaseController
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

        # { namespace_name => nested i18next tree }. Skips namespaces with no
        # values for this locale so the client never types empty branches.
        def compile(locale)
          @project.namespaces.order(:name).each_with_object({}) do |namespace, out|
            tree = tree_for(namespace, locale)
            out[namespace.name] = tree unless tree.empty?
          end
        end

        def tree_for(namespace, locale)
          if include_drafts?
            JSON.parse(NamespaceExport.new(namespace, locales: [ locale ], include_drafts: true).content(locale, "json"))
          else
            TranslationBundle.new(namespace: namespace, locale: locale).to_h
          end
        end

        def include_drafts?
          ActiveModel::Type::Boolean.new.cast(params[:include_drafts])
        end
    end
  end
end
