# Public, unauthenticated JSON delivery for i18n clients. Serves the published
# translations of one (project, locale, namespace) as a nested object, matching
# the i18next http-backend loadPath "/cdn/:project/:locale/:namespace.json".
# HTTP caching (ETag + Cache-Control) lets the host decide when to re-fetch.
class DeliveryController < ApplicationController
  allow_unauthenticated only: :show

  def show
    project = Project.find_by!(slug: params[:project_slug])
    locale = project.locales.find_by!(code: params[:locale])
    namespace = project.namespaces.find_by!(name: namespace_name)

    artifact = Translation::Artifact.find_by(namespace: namespace, locale: locale)
    if artifact&.file&.attached?
      serve_artifact(artifact)
    else
      serve_live(namespace, locale)
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private
    def serve_artifact(artifact)
      if stale?(etag: artifact.checksum, public: true)
        set_cache_headers
        render body: artifact.file.download, content_type: "application/json"
      end
    end

    def serve_live(namespace, locale)
      bundle = TranslationBundle.new(namespace: namespace, locale: locale)
      if stale?(etag: bundle.etag, public: true)
        set_cache_headers
        render json: bundle.to_h
      end
    end

    # A CDN fronts this endpoint (see docs/cdn-setup.md): cache for an hour, but
    # serve stale up to 5 minutes while revalidating so a publish propagates
    # quickly without a thundering herd against the origin.
    def set_cache_headers
      expires_in 1.hour, public: true, "stale-while-revalidate": 5.minutes.to_i
    end

    # The route captures ".json" into :namespace (namespaces may contain dots),
    # so strip a single trailing ".json" to support both loadPath styles.
    def namespace_name
      params[:namespace].delete_suffix(".json")
    end
end
