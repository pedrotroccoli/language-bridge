require "test_helper"

class StorageConnectionsControllerTest < ActionDispatch::IntegrationTest
  test "admin adds a connection (first one becomes default)" do
    sign_in_as(users(:admin))
    assert_difference -> { StorageConnection.count }, 1 do
      post storage_connections_path, params: { storage_connection: { name: "Prod", service: "s3", bucket: "my-bucket", inherit_credentials: "1" } }
    end
    assert_redirected_to workspace_path
    assert StorageConnection.last.is_default
  end

  test "admin updates a connection, blank secret keeps the stored one" do
    sign_in_as(users(:admin))
    connection = StorageConnection.create!(name: "Prod", service: "s3", bucket: "b", access_key_id: "AKIA", secret_access_key: "kept")

    patch storage_connection_path(connection), params: { storage_connection: { name: "Renamed", service: "s3", bucket: "b", access_key_id: "AKIA", secret_access_key: "" } }

    assert_redirected_to workspace_path
    assert_equal "Renamed", connection.reload.name
    assert_equal "kept", connection.secret_access_key
  end

  test "admin makes a connection default and removes one" do
    sign_in_as(users(:admin))
    a = StorageConnection.create!(name: "A", service: "local", is_default: true)
    b = StorageConnection.create!(name: "B", service: "local")

    post storage_connection_default_path(b)
    assert b.reload.is_default
    assert_not a.reload.is_default

    assert_difference -> { StorageConnection.count }, -1 do
      delete storage_connection_path(a)
    end
  end

  test "test endpoint verifies a local connection" do
    sign_in_as(users(:admin))
    post test_storage_connections_path, params: { storage_connection: { name: "Local", service: "local" } }
    assert_response :success
    assert JSON.parse(response.body)["ok"]
  end

  test "non-admin is blocked" do
    sign_in_as(users(:translator))
    post storage_connections_path, params: { storage_connection: { name: "X", service: "local" } }
    assert_redirected_to root_path
  end
end
