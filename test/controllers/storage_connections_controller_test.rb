require "test_helper"

class StorageConnectionsControllerTest < ActionDispatch::IntegrationTest
  test "admin adds a connection (first one becomes default)" do
    sign_in_as(users(:admin))
    assert_difference -> { StorageConnection.count }, 1 do
      post storage_connections_path, params: { storage_connection: { name: "Prod", service_name: "test", bucket: "my-bucket" } }
    end
    assert_redirected_to workspace_path
    assert StorageConnection.last.is_default
  end

  test "admin makes a connection default and removes one" do
    sign_in_as(users(:admin))
    a = StorageConnection.create!(name: "A", service_name: "test", is_default: true)
    b = StorageConnection.create!(name: "B", service_name: "local")

    post storage_connection_default_path(b)
    assert b.reload.is_default
    assert_not a.reload.is_default

    assert_difference -> { StorageConnection.count }, -1 do
      delete storage_connection_path(a)
    end
  end

  test "non-admin is blocked" do
    sign_in_as(users(:translator))
    post storage_connections_path, params: { storage_connection: { name: "X", service_name: "test" } }
    assert_redirected_to root_path
  end
end
