module Api
  module V1
    # Push counterpart of the export endpoint: an AI (or any save_missing token)
    # proposes source-locale translations. Nothing goes live — each value lands
    # as a Translation::Proposal a human reviews and accepts/rejects, so an
    # automated push can never clobber a published string. Body mirrors the
    # export shape, so `lb pull` output round-trips through `lb push`.
    #
    #   POST /api/v1/projects/:project_slug/import
    #   { "locale": "en", "session": "feat/cli",
    #     "namespaces": { "common": { "home": { "title": "Welcome" } } } }
    #
    # An optional `session` (git branch or AI chat) keeps parallel work streams
    # separate: two branches may each propose the same key without clobbering.
    # Proposals target the source locale only — the platform translates the rest.
    # Requires a user-scoped token (PAT) so the proposer is recorded.
    class ImportsController < Api::BaseController
      before_action -> { require_scope!(:save_missing) }

      MAX_KEYS = 2000

      def create
        author = token_user
        return render_error(:unprocessable_entity, "A user-scoped token (PAT) is required to propose") if author.nil?
        return render_error(:unprocessable_entity, "locale is required") if params[:locale].blank?

        locale = @project.locales.find_by(code: params[:locale])
        return render_error(:not_found, "Locale not found") if locale.nil?
        return render_error(:unprocessable_entity, "Only the source locale accepts proposals") unless locale.is_source

        entries = flatten_namespaces(params[:namespaces])
        return render_error(:unprocessable_entity, "namespaces must be a non-empty object") if entries.empty?
        return render_error(:unprocessable_entity, "too many keys (max #{MAX_KEYS})") if entries.size > MAX_KEYS

        proposed = create_proposals(entries, locale, author, params[:session].to_s)
        render json: { status: "ok", locale: locale.code, session: params[:session].to_s, proposed: proposed.size }
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

        def create_proposals(entries, locale, author, session)
          namespaces = {}
          entries.map do |entry|
            namespace = namespaces[entry[:namespace]] ||= @project.namespaces.find_or_create_by!(name: entry[:namespace])
            Translation::Proposal.propose(namespace: namespace, key: entry[:key], locale: locale, value: entry[:value], author: author, session: session)
          end
        end
    end
  end
end
