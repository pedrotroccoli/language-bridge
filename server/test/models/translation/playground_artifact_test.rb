require "test_helper"

class Translation::PlaygroundArtifactTest < ActiveSupport::TestCase
  setup do
    @namespace = namespaces(:main_app_common)
    @locale = locales(:main_app_en)
    @key = Translation::PlaygroundArtifact.storage_key(@namespace.project, @namespace, @locale)
  end

  test "editing a draft value rebuilds the playground file" do
    translations(:greeting_en).update!(value: "Hey there")

    json = JSON.parse(ActiveStorage::Blob.service.download(@key))
    assert_equal "Hey there", json["greeting"]
  end

  test "destroying a draft rebuilds the playground without it" do
    translations(:greeting_en).update!(value: "Hey")
    translations(:greeting_en).destroy!

    json = JSON.parse(ActiveStorage::Blob.service.download(@key))
    assert_nil json["greeting"]
  end

  test "batch defers rebuilds until the block exits" do
    ActiveStorage::Blob.service.delete(@key) # a prior test may have written it

    Translation::PlaygroundArtifact.batch do
      translations(:greeting_en).update!(value: "Deferred")
      assert_not ActiveStorage::Blob.service.exist?(@key), "write should wait for the batch"
    end

    json = JSON.parse(ActiveStorage::Blob.service.download(@key))
    assert_equal "Deferred", json["greeting"]
  end
end
