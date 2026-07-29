require "test_helper"
require "zip"

class NamespaceExportTest < ActiveSupport::TestCase
  setup do
    @project = projects(:main_app)
    @namespace = namespaces(:main_app_common)
    @en = locales(:main_app_en)
    @pt = locales(:main_app_pt_br)
  end

  test "JSON expands dotted keys into nested objects" do
    key = @namespace.translation_keys.create!(project: @project, key: "home.title")
    Translation.create!(project: @project, translation_key: key, locale: @en, value: "Welcome")

    file = NamespaceExport.new(@namespace, locales: [ @en ]).download("json")
    data = JSON.parse(file.body)

    assert_equal "Welcome", data.dig("home", "title")
    assert_equal "Hello", data["greeting"]
  end

  test "empty values are omitted" do
    file = NamespaceExport.new(@namespace, locales: [ @en ]).download("json")
    data = JSON.parse(file.body)

    assert_not data.key?("farewell") # farewell_en_missing has a blank value
  end

  test "multiple locales bundle into a zip of per-locale files" do
    file = NamespaceExport.new(@namespace, locales: [ @en, @pt ]).download("json")
    assert_equal "application/zip", file.content_type

    entries = {}
    Zip::InputStream.open(StringIO.new(file.body)) do |io|
      while (entry = io.get_next_entry)
        entries[entry.name] = io.read
      end
    end

    assert_equal %w[ en.json pt-BR.json ], entries.keys.sort
    assert_equal "Olá", JSON.parse(entries["pt-BR.json"])["greeting"]
  end

  test "export round-trips back through TranslationImport" do
    body = NamespaceExport.new(@namespace, locales: [ @en ]).download("json").body

    # Re-importing the exported file leaves the value intact.
    TranslationImport.new(namespace: @namespace, locale: @en, author: users(:translator), format: "json").import(body)

    value = @namespace.translation_keys.find_by(key: "greeting").translations.find_by(locale: @en).value
    assert_equal "Hello", value
  end

  test "unsupported format raises" do
    assert_raises(NamespaceExport::Error) do
      NamespaceExport.new(@namespace, locales: [ @en ]).download("yaml")
    end
  end
end
