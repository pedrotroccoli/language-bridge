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
    assert_equal({ "greeting" => "Hello" }, JSON.parse(artifact.file.download))
    assert_equal TranslationBundle.new(namespace: @namespace, locale: @locale).etag, artifact.checksum
  end

  test "unpublishing rebuilds the artifact without the translation" do
    @translation.publish(by: users(:admin))
    @translation.unpublish
    assert_equal({}, JSON.parse(artifact_for.file.download))
  end

  test "editing a published value rebuilds the artifact" do
    @translation.publish(by: users(:admin))
    @translation.update!(value: "Hi", author: users(:admin)) # discards publication
    assert_equal({}, JSON.parse(artifact_for.file.download))
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
end
