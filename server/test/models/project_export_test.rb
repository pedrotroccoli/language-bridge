require "test_helper"
require "zip"

class ProjectExportTest < ActiveSupport::TestCase
  setup do
    @project = projects(:main_app)
  end

  def entries(format)
    body = ProjectExport.new(@project).download(format).body
    map = {}
    Zip::InputStream.open(StringIO.new(body)) do |io|
      while (entry = io.get_next_entry)
        map[entry.name] = io.read
      end
    end
    map
  end

  test "bundles every namespace x locale under <locale>/<namespace>.<ext>" do
    files = entries("json")

    assert_includes files.keys, "en/common.json"
    assert_includes files.keys, "pt-BR/common.json"
    assert_equal "Hello", JSON.parse(files["en/common.json"])["greeting"]
    assert_equal "Olá", JSON.parse(files["pt-BR/common.json"])["greeting"]
  end

  test "namespaces with no values for a locale are skipped" do
    # main_app_marketing has no translations in fixtures -> no entries for it.
    assert_empty entries("json").keys.grep(%r{/marketing\.json\z})
  end

  test "download is always a zip" do
    file = ProjectExport.new(@project).download("json")
    assert_equal "application/zip", file.content_type
    assert_equal "main-app-json.zip", file.filename
  end

  test "unsupported format raises" do
    assert_raises(NamespaceExport::Error) { ProjectExport.new(@project).download("yaml") }
  end
end
