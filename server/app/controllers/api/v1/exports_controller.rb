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
      before_action -> { require_capability!(:read) }
      before_action -> { require_capability!(:read_drafts) }, if: :include_drafts?

      def show
        locale = resolve_locale
        return render_error(:not_found, "Locale not found") if locale.nil?

        render json: payload(locale)
      end

      private
        def payload(locale)
          {
            project: @project.slug,
            locale: locale.code,
            is_source: locale.is_source,
            namespaces: LocaleBundle.new(@project, locale, include_drafts: include_drafts?).to_h,
            available_locales: @project.locales.order(:code).pluck(:code),
            source_locale: @project.source_locale&.code
          }
        end

        def resolve_locale
          code = params[:locale].presence
          code ? @project.locales.find_by(code: code) : @project.source_locale
        end

        def include_drafts?
          params[:include_drafts].present?
        end
    end
  end
end
