require "test_helper"

class Translation::ArtifactDeliveryKeyTest < ActiveSupport::TestCase
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)   # common
    @locale = locales(:main_app_en)             # en
    @translation = translations(:greeting_en)   # key "greeting", value "Hello"
    @translation.publish                        # gives the bundle published content
  end

  def rebuild
    Translation::Artifact.rebuild(@namespace.id, @locale.id)
  end

  test "rebuild stores the blob at the deterministic template key" do
    artifact = rebuild
    assert artifact.file.attached?
    assert_equal "main-app/common/en.json", artifact.file.key
  end

  test "a content edit reuses the same blob and key in place" do
    artifact = rebuild
    key = artifact.file.key
    blob_id = artifact.file.blob.id
    old_checksum = artifact.checksum

    @translation.update!(value: "Hi there")
    @translation.publish
    artifact = rebuild

    assert_equal key, artifact.file.key, "key must stay stable across edits"
    assert_equal blob_id, artifact.file.blob.id, "same blob reused (in-place upload, no churn)"
    assert_not_equal old_checksum, artifact.reload.checksum
    assert_match "Hi there", artifact.file.download
  end

  test "changing the template re-keys and purges the old blob" do
    artifact = rebuild
    old_blob = artifact.file.blob

    @project.update!(delivery_path_template: "i18n/{locale}/{namespace}.json")
    artifact = rebuild

    assert_equal "i18n/en/common.json", artifact.file.key
    assert_not ActiveStorage::Blob.exists?(old_blob.id), "old blob must be purged"
  end
end
