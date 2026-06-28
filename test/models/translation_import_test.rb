require "test_helper"

class TranslationImportTest < ActiveSupport::TestCase
  setup do
    @namespace = namespaces(:main_app_common)
    @locale = locales(:main_app_en)
    @author = users(:admin)
  end

  test "flattens nested objects to dotted keys" do
    import({ a: { b: { c: "deep" } }, x: "flat" }.to_json)
    assert @namespace.translation_keys.exists?(key: "a.b.c")
    assert @namespace.translation_keys.exists?(key: "x")
    assert_equal "deep", value("a.b.c")
  end

  test "stringifies non-string leaves" do
    import({ n: 3, b: true, arr: [ 1, 2 ], nothing: nil }.to_json)
    assert_equal "3", value("n")
    assert_equal "true", value("b")
    assert_equal "[1,2]", value("arr")
    assert_equal "", value("nothing")
  end

  test "overwrites existing value and snapshots a version" do
    existing = translations(:greeting_en) # value "Hello"
    assert_difference -> { existing.versions.count }, 1 do
      import({ greeting: "Hi" }.to_json)
    end
    assert_equal "Hi", existing.reload.value
    assert_equal "Hello", existing.versions.order(:created_at).last.value
  end

  test "counts created keys and written translations" do
    result = import({ greeting: "x", brand_new: "y" }.to_json)
    assert_equal 1, result.keys_created
    assert_equal 2, result.translations_written
  end

  test "records a project event for the import" do
    assert_difference -> { @namespace.project.events.where(action: "translations_imported").count }, 1 do
      import({ greeting: "x", brand_new: "y" }.to_json)
    end
    event = @namespace.project.events.where(action: "translations_imported").last
    assert_equal @author, event.creator
    assert_equal "en", event.metadata["locale"]
    assert_equal 1, event.metadata["keys_created"]
  end

  test "raises on non-object json" do
    assert_raises(TranslationImport::Error) { import("[1,2,3]") }
  end

  test "raises on invalid json" do
    assert_raises(TranslationImport::Error) { import("{ not json") }
  end

  test "raises on empty object" do
    assert_raises(TranslationImport::Error) { import("{}") }
  end

  private
    def import(json)
      TranslationImport.new(namespace: @namespace, locale: @locale, author: @author).import(json)
    end

    def value(key)
      @namespace.translation_keys.find_by(key: key).translations.find_by(locale: @locale).value
    end
end
