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

  test "recomputes counter caches after a bulk import" do
    import({ greeting: "x", brand_new: "y" }.to_json)
    new_key = @namespace.translation_keys.find_by(key: "brand_new")
    assert_equal 1, new_key.reload.translations_count
    assert_equal @namespace.translation_keys.count, @namespace.reload.translation_keys_count
    assert_equal @namespace.project.translation_keys.count, @namespace.project.reload.translation_keys_count
    assert_equal @locale.translations.count, @locale.reload.translations_count
  end

  test "snapshots the previous value with its author when re-import changes it" do
    existing = translations(:greeting_en) # value "Hello"
    existing.update!(author: @author)
    import({ greeting: "Hi" }.to_json)
    version = existing.versions.order(:created_at).last
    assert_equal "Hello", version.value
    assert_equal @author.id, version.author_id
  end

  test "discards a stale publication when a re-import changes a published value" do
    published = translations(:greeting_en)
    published.publish(by: @author)
    assert published.reload.published?

    import({ greeting: "Changed" }.to_json)

    assert_not published.reload.published?
    event = @namespace.project.events.where(action: "translations_imported").last
    assert_equal 1, event.metadata["publications_discarded"]
  end

  test "keeps publication and writes no version when re-imported value is unchanged" do
    published = translations(:greeting_en) # "Hello"
    published.publish(by: @author)

    assert_no_difference -> { published.versions.count } do
      import({ greeting: "Hello" }.to_json)
    end
    assert published.reload.published?
  end

  test "resets approval when a re-import changes the value" do
    approved = translations(:greeting_en)
    approved.approve(by: @author)
    assert approved.reload.approved?

    import({ greeting: "Changed" }.to_json)

    assert_not approved.reload.approved?
  end

  test "imports correctly across multiple batches" do
    result = TranslationImport.new(namespace: @namespace, locale: @locale, author: @author, batch_size: 1)
                              .import({ a: "1", b: "2", c: "3" }.to_json)
    assert_equal 3, result.translations_written
    assert_equal "1", value("a")
    assert_equal "3", value("c")
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

  test "imports a CSV file by key/value columns" do
    result = TranslationImport.new(namespace: @namespace, locale: @locale, author: @author, format: "csv")
                              .import("key,value\ngreeting,Hi\nbrand_new,Y\n")
    assert_equal "Hi", value("greeting")
    assert_equal "Y", value("brand_new")
    assert_equal 1, result.keys_created
  end

  test "imports an XLIFF file by trans-unit target" do
    xliff = <<~XML
      <?xml version="1.0"?>
      <xliff version="1.2"><file original="common" source-language="en" target-language="en"><body>
        <trans-unit id="greeting" resname="greeting"><source>Hello</source><target>Hi there</target></trans-unit>
      </body></file></xliff>
    XML
    TranslationImport.new(namespace: @namespace, locale: @locale, author: @author, format: "xliff").import(xliff)
    assert_equal "Hi there", value("greeting")
  end

  test "detects format from filename extension" do
    assert_equal "csv", TranslationImport.format_from_filename("data.csv")
    assert_equal "xliff", TranslationImport.format_from_filename("data.xlf")
    assert_equal "json", TranslationImport.format_from_filename("data.unknown")
  end

  private
    def import(json)
      TranslationImport.new(namespace: @namespace, locale: @locale, author: @author).import(json)
    end

    def value(key)
      @namespace.translation_keys.find_by(key: key).translations.find_by(locale: @locale).value
    end
end
