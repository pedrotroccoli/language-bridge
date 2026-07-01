require "test_helper"

class Translation::ArtifactTest < ActiveSupport::TestCase
  setup do
    @namespace = namespaces(:main_app_common)
    @locale = locales(:main_app_en)
    @translation = translations(:greeting_en) # "Hello"
  end

  test "publishing materializes an artifact with the compiled file" do
    assert_difference -> { Translation::Artifact.count }, 1 do
      @translation.publish(by: users(:admin))
    end
    artifact = artifact_for
    assert artifact.file.attached?
    assert_equal({ "greeting" => "Hello" }, payload(artifact))
    assert_equal TranslationBundle.new(namespace: @namespace, locale: @locale).etag, artifact.checksum
  end

  test "stores the blob gzip-compressed with content_encoding by default" do
    @translation.publish(by: users(:admin))
    artifact = artifact_for

    assert_equal "gzip", artifact.content_encoding
    raw = artifact.file.download
    assert_raises(JSON::ParserError) { JSON.parse(raw) } # the stored bytes are not plain JSON
    assert_equal({ "greeting" => "Hello" }, JSON.parse(ActiveSupport::Gzip.decompress(raw)))
  end

  test "stores the blob uncompressed when delivery_compression is none" do
    Setting.current.update!(delivery_compression: "none")

    @translation.publish(by: users(:admin))
    artifact = artifact_for

    assert_nil artifact.content_encoding
    assert_equal({ "greeting" => "Hello" }, JSON.parse(artifact.file.download))
  end

  test "checksum stays the logical-JSON etag regardless of compression" do
    @translation.publish(by: users(:admin))
    assert_equal TranslationBundle.new(namespace: @namespace, locale: @locale).etag, artifact_for.checksum
  end

  test "published artifact is routed to the project's storage connection and prefix" do
    connection = StorageConnection.create!(name: "Bucket", service: "local", prefix: "lb-poc", is_default: true)

    @translation.publish(by: users(:admin))
    artifact = artifact_for

    assert_equal connection.service_key, artifact.file.blob.service_name
    assert artifact.file.key.start_with?("lb-poc/"), "expected key under the connection prefix, got #{artifact.file.key}"
  end

  test "unpublishing rebuilds the artifact without the translation" do
    @translation.publish(by: users(:admin))
    @translation.unpublish
    assert_equal({}, payload(artifact_for))
  end

  test "editing a published value rebuilds the artifact" do
    @translation.publish(by: users(:admin))
    @translation.update!(value: "Hi", author: users(:admin)) # discards publication
    assert_equal({}, payload(artifact_for))
  end

  test "batch defers rebuilds and coalesces the same pair into one artifact" do
    Translation::Artifact.batch do
      @translation.publish(by: users(:admin))
      translations(:farewell_en_missing).publish(by: users(:admin)) # same namespace+locale
      assert_equal 0, Translation::Artifact.count, "rebuild should be deferred until the block exits"
    end
    assert_equal 1, Translation::Artifact.count
  end

  test "rebuild upserts a single artifact per namespace and locale" do
    Translation::Artifact.rebuild(@namespace.id, @locale.id)
    assert_no_difference -> { Translation::Artifact.count } do
      Translation::Artifact.rebuild(@namespace.id, @locale.id)
    end
  end

  test "batch rebuilds touched pairs even when the block raises" do
    assert_raises(RuntimeError) do
      Translation::Artifact.batch do
        @translation.publish(by: users(:admin))
        raise "boom"
      end
    end
    assert Translation::Artifact.exists?(namespace: @namespace, locale: @locale)
  end

  test "destroying the namespace removes its artifacts" do
    @translation.publish(by: users(:admin))
    assert_difference -> { Translation::Artifact.count }, -1 do
      @namespace.destroy!
    end
  end

  test "destroying the locale removes its artifacts" do
    @translation.publish(by: users(:admin))
    assert_difference -> { Translation::Artifact.count }, -1 do
      @locale.destroy!
    end
  end

  private
    def artifact_for
      Translation::Artifact.find_by!(namespace: @namespace, locale: @locale)
    end

    # Stored blobs are compression-encoded; decode before parsing.
    def payload(artifact)
      JSON.parse(DeliveryCompression.decompress(artifact.file.download, artifact.content_encoding))
    end
end
