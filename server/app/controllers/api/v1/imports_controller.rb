module Api
  module V1
    # Push counterpart of the export endpoint: an AI (or any save_missing token)
    # writes source-locale translations as draft edits, tagged with the push
    # `session` (git branch or chat). Nothing is published — each value lands as a
    # normal Unpublished row in the editor, reviewable/publishable in place and
    # filterable by session (see `lb review`). Body mirrors the export shape, so
    # `lb pull` output round-trips through `lb push`.
    #
    #   POST /api/v1/projects/:project_slug/import
    #   { "locale": "en", "session": "feat/cli",
    #     "namespaces": { "common": { "home": { "title": "Welcome" } } } }
    #
    # Editing an already-published key returns it to draft, exactly like an editor
    # edit. Any of the project's locales accepts pushes — everything lands as a
    # draft, so review-before-publish is the safety net, not the locale. Requires
    # a user-scoped token (PAT) so the author is recorded.
    class ImportsController < Api::BaseController
      before_action -> { require_capability!(:write) }

      MAX_KEYS = 2000

      def create
        author = token_user
        return render_error(:unprocessable_entity, "A user-scoped token (PAT) is required to push") if author.nil?
        return render_error(:unprocessable_entity, "locale is required") if params[:locale].blank?

        locale = @project.locales.find_by(code: params[:locale])
        return render_error(:not_found, "Locale not found") if locale.nil?

        entries = flatten_namespaces(params[:namespaces])
        return render_error(:unprocessable_entity, "namespaces must be a non-empty object") if entries.empty?
        return render_error(:unprocessable_entity, "too many keys (max #{MAX_KEYS})") if entries.size > MAX_KEYS

        session = params[:session].to_s
        # Coalesce the per-row playground rebuilds a bulk push would trigger into
        # one write per (namespace, locale), and the per-row project touches
        # (last-activity stamp) into a single touch.
        written = Project.no_touching do
          Translation::PlaygroundArtifact.batch { write_drafts(entries, locale, author, session) }
        end
        @project.touch
        # Materialize the session's preview JSON in the connected storage so a
        # frontend can point at the push at a stable path before anything publishes.
        preview_paths = Translation::SessionArtifact.materialize_session(@project, session)
        playground_paths = Translation::PlaygroundArtifact.ensure_materialized(@project, entries.map { |entry| entry[:namespace] }.uniq, locale)
        render json: { status: "ok", locale: locale.code, session: session, written: written,
                       preview_paths: preview_paths, playground_paths: playground_paths }
      rescue ActiveRecord::RecordInvalid => e
        render_error(:unprocessable_entity, e.message)
      end

      private
        # [{ namespace:, key:, value: }] flattened from { ns => nested tree }.
        def flatten_namespaces(namespaces)
          return [] unless namespaces.is_a?(ActionController::Parameters)

          namespaces.to_unsafe_h.flat_map do |name, tree|
            next [] unless tree.is_a?(Hash)

            TranslationTree.flatten(tree).map { |key, value| { namespace: name.to_s, key: key, value: value } }
          end
        end

        # Create/update each draft translation, creating keys and namespaces as
        # needed. Returns how many were written.
        def write_drafts(entries, locale, author, session)
          namespaces = {}
          keys = {}
          entries.each do |entry|
            namespace = namespaces[entry[:namespace]] ||= @project.namespaces.find_or_create_by!(name: entry[:namespace])
            key = keys[[ namespace.id, entry[:key] ]] ||= namespace.translation_keys.find_or_create_by!(key: entry[:key]) { |record| record.project = @project }
            key.set_translation(locale: locale, value: entry[:value], author: author, session: session.presence)
          end
          entries.size
        end
    end
  end
end
