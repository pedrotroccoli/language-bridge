# Teach Active Storage's service registry to resolve "sc_<id>" service names by
# building the service from the matching StorageConnection on demand and caching
# it for the process. This lets blobs attached to a connection be validated,
# uploaded, downloaded and restored from any process without pre-declaring every
# connection in config/storage.yml.
module StorageConnectionRegistry
  def fetch(name)
    return super unless name.to_s.start_with?("sc_")

    @services.fetch(name.to_sym) do
      connection = StorageConnection.find_by(id: name.to_s.delete_prefix("sc_"))
      # Unknown connection → fall back to the default behavior (yields the caller's
      # block, e.g. the Blob service_name validation, or raises for missing config).
      next super unless connection

      @services[name.to_sym] = connection.build_active_storage_service
    end
  end
end

Rails.application.config.to_prepare do
  ActiveStorage::Service::Registry.prepend(StorageConnectionRegistry)
end
