module Api
  module V1
    # Receives an i18next `saveMissing` payload and records each unknown key in
    # the project's missing-key triage inbox (MissingKeyReport) — bumping hit
    # counts and the locales that requested it. It does NOT create real keys;
    # an editor promotes reports from the Missing tab. Idempotent: replaying a
    # payload just increments hits.
    #
    #   POST /api/v1/projects/:project_slug/missing
    #   { "locale": "en", "namespace": "common",
    #     "keys": { "home.title": "Welcome", "nav.signup": "Sign up" } }
    class MissingTranslationsController < Api::BaseController
      before_action -> { require_scope!(:save_missing) }

      MAX_KEYS_PER_REQUEST = 500

      def create
        keys = params[:keys]
        return render_error(:unprocessable_entity, "keys must be a non-empty object") unless keys.is_a?(ActionController::Parameters) && keys.keys.any?
        return render_error(:unprocessable_entity, "too many keys (max #{MAX_KEYS_PER_REQUEST})") if keys.keys.size > MAX_KEYS_PER_REQUEST
        return render_error(:unprocessable_entity, "locale is required")    if params[:locale].blank?
        return render_error(:unprocessable_entity, "namespace is required") if params[:namespace].blank?

        keys.keys.each do |key_path|
          MissingKeyReport.record!(project: @project, namespace: params[:namespace], key: key_path, locale: params[:locale])
        end

        render json: { status: "ok", reported: keys.keys.size }
      rescue ActiveRecord::RecordInvalid => e
        render_error(:unprocessable_entity, e.message)
      end
    end
  end
end
