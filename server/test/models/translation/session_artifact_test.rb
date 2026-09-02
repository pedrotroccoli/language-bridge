require "test_helper"

class Translation::SessionArtifactTest < ActiveSupport::TestCase
  setup do
    @namespace = namespaces(:main_app_common)
    @locale = locales(:main_app_en)
    @project = @namespace.project
  end

  test "storage key nests the session under sessions/" do
    key = Translation::SessionArtifact.storage_key(@project, @namespace, @locale, "feat/cli-push")

    assert_includes key, "sessions/feat/cli-push/"
  end

  test "unsafe characters in the session are replaced" do
    key = Translation::SessionArtifact.storage_key(@project, @namespace, @locale, "feat cli push!")

    assert_includes key, "sessions/feat-cli-push-/"
  end

  test "dot-only segments cannot traverse out of the storage root" do
    key = Translation::SessionArtifact.storage_key(@project, @namespace, @locale, "../../../etc/passwd")

    assert_not_includes key.split("/"), ".."
    assert_not_includes key.split("/"), "."
    assert_includes key, "sessions/etc/passwd/"
  end
end
