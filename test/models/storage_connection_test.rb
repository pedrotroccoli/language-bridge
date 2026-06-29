require "test_helper"

class StorageConnectionTest < ActiveSupport::TestCase
  test "validates the service against the known service kinds" do
    assert StorageConnection.new(name: "Prod", service: "local").valid?
    invalid = StorageConnection.new(name: "Bad", service: "nope")
    assert_not invalid.valid?
  end

  test "cloud connections require a bucket" do
    connection = StorageConnection.new(name: "S3", service: "s3", inherit_credentials: true)
    assert_not connection.valid?
    assert_includes connection.errors[:bucket], "can't be blank"
  end

  test "cloud connections that store credentials require both key and secret" do
    connection = StorageConnection.new(name: "S3", service: "s3", bucket: "b")
    assert_not connection.valid?
    assert connection.errors[:access_key_id].any?
    assert connection.errors[:secret_access_key].any?
  end

  test "inheriting credentials skips the key/secret requirement" do
    connection = StorageConnection.new(name: "S3", service: "s3", bucket: "b", inherit_credentials: true)
    assert connection.valid?
    assert connection.usable?
    assert_not connection.needs_credentials?
  end

  test "secret is encrypted at rest and decrypts in memory" do
    connection = StorageConnection.create!(name: "S3", service: "s3", bucket: "b", region: "us-east-1",
                                           access_key_id: "AKIA", secret_access_key: "top-secret")
    raw = StorageConnection.connection.select_value(
      "SELECT secret_access_key FROM storage_connections WHERE id = #{StorageConnection.connection.quote(connection.id)}"
    )
    assert_not_includes raw.to_s, "top-secret"
    assert_equal "top-secret", StorageConnection.find(connection.id).secret_access_key
  end

  test "marking a connection default unsets the others" do
    a = StorageConnection.create!(name: "A", service: "local", is_default: true)
    b = StorageConnection.create!(name: "B", service: "local", is_default: true)

    assert_not a.reload.is_default
    assert b.reload.is_default
    assert_equal b, StorageConnection.default
  end

  test "builds a usable Active Storage service for a local connection" do
    connection = StorageConnection.create!(name: "Local", service: "local")
    service = connection.build_active_storage_service
    assert_kind_of ActiveStorage::Service::DiskService, service
  end
end
