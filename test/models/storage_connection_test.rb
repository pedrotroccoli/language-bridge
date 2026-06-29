require "test_helper"

class StorageConnectionTest < ActiveSupport::TestCase
  test "validates the service against configured Active Storage services" do
    assert StorageConnection.new(name: "Prod", service_name: "test").valid?
    invalid = StorageConnection.new(name: "Bad", service_name: "nope")
    assert_not invalid.valid?
    assert_match(/configured storage service/, invalid.errors[:service_name].join)
  end

  test "marking a connection default unsets the others" do
    a = StorageConnection.create!(name: "A", service_name: "test", is_default: true)
    b = StorageConnection.create!(name: "B", service_name: "local", is_default: true)

    assert_not a.reload.is_default
    assert b.reload.is_default
    assert_equal b, StorageConnection.default
  end
end
