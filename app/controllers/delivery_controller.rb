# Public, unauthenticated JSON delivery for i18n clients. Serves the published
# translations of one (project, locale, namespace) as a nested object, matching
# the i18next http-backend loadPath "/cdn/:project/:locale/:namespace.json".
# HTTP caching (ETag + Cache-Control) lets the host decide when to re-fetch.
class DeliveryController < ApplicationController
  include ActiveStorage::Streaming

  allow_unauthenticated only: :show

  def show
    project = Project.find_by!(slug: params[:project_slug])
    locale = project.locales.find_by!(code: params[:locale])
    namespace = find_namespace!(project)

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
    # Stream the stored blob chunk by chunk instead of loading it whole into
    # memory. Cache headers are set before the freshness check so a 304 carries
    # them too.
    def serve_artifact(artifact)
      set_cache_headers
      send_blob_stream(artifact.file, disposition: "inline") if stale?(etag: artifact.checksum)
    end

    def serve_live(namespace, locale)
      bundle = TranslationBundle.new(namespace: namespace, locale: locale)
      set_cache_headers
      render json: bundle.to_h if stale?(etag: bundle.etag)
    end

    # A CDN fronts this endpoint (see docs/cdn-setup.md): cache for an hour, but
    # serve stale up to 5 minutes while revalidating so a publish propagates
    # quickly without a thundering herd against the origin.
    def set_cache_headers
      expires_in 1.hour, public: true, "stale-while-revalidate": 5.minutes.to_i
    end

    # The route captures ".json" into :namespace (namespaces may contain dots),
    # so the optional loadPath suffix can't be a Rails format. Try the literal
    # name first (a namespace really named "x.json"), then the stripped form.
    def find_namespace!(project)
      raw = params[:namespace]
      project.namespaces.find_by(name: raw) ||
        project.namespaces.find_by!(name: raw.delete_suffix(".json"))
    end
end
