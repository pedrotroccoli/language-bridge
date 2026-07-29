class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  helper_method :storage_configured?

  # Whether a usable cloud bucket is connected — drives the global "no storage"
  # banner. Memoized per request so the layout doesn't re-query on every render.
  def storage_configured?
    return @storage_configured if defined?(@storage_configured)

    @storage_configured = StorageConnection.usable_cloud_exists?
  end
end
