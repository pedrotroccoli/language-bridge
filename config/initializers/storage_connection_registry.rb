# Teach Active Storage's service registry to resolve "sc_<id>" service names by
# building the service from the matching StorageConnection on demand. This lets
# blobs attached to a connection be uploaded, downloaded and restored from any
# process without pre-declaring every connection in config/storage.yml.
module StorageConnectionRegistry
  def fetch(name)
    super
  rescue StandardError => e
    raise unless name.to_s.start_with?("sc_")

    id = name.to_s.delete_prefix("sc_")
    connection = StorageConnection.find_by(id: id) or raise e

    service = connection.build_active_storage_service
    # Cache for the life of the process, mirroring the registry's own behavior.
    services = instance_variable_get(:@services)
    services[name.to_sym] = service
  end
end

Rails.application.config.to_prepare do
  ActiveStorage::Service::Registry.prepend(StorageConnectionRegistry)
end
