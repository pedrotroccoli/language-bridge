# Verifies a storage connection can actually be reached and written to, by
# round-tripping a tiny probe object (upload → exist? → delete). Returns a
# Result with ok? and a human message for the connection modal.
class StorageConnection::Tester
  Result = Struct.new(:ok, :message, keyword_init: true) do
    def ok? = ok
  end

  PROBE_KEY = "__language_bridge_connection_test__"

  def self.call(connection) = new(connection).call

  def initialize(connection)
    @connection = connection
  end

  def call
    service = @connection.build_active_storage_service
    key = @connection.key_for(PROBE_KEY) # written under the connection's prefix
    service.upload(key, StringIO.new("ok"), checksum: probe_checksum)
    service.delete(key)
    Result.new(ok: true, message: "Connection verified")
  rescue LoadError => e
    Result.new(ok: false, message: "Adapter not installed: #{e.message}")
  rescue StandardError => e
    Result.new(ok: false, message: e.message.truncate(200))
  end

  private
    def probe_checksum
      OpenSSL::Digest::MD5.base64digest("ok")
    end
end
