require "test_helper"

class SnapshotTest < ActiveSupport::TestCase
  SAMPLE = {
    "version" => TranslationSnapshot::VERSION,
    "locales" => [ "en", "pt-BR" ],
    "namespaces" => {
      "common" => {
        "a.greeting" => {
          "en"    => { "value" => "Hello", "published" => true },
          "pt-BR" => { "value" => "Olá", "published" => false }
        }
      }
    }
  }.freeze

  %w[ json csv xliff ].each do |format|
    test "#{format} round-trips value, published flag and locales" do
      body, content_type, extension = Snapshot.dump(SAMPLE, format: format)
      assert_equal format, extension
      assert content_type.present?

      back = Snapshot.load(body, format: format)
      entry = back["namespaces"]["common"]["a.greeting"]
      assert_equal "Olá", entry["pt-BR"]["value"]
      assert_equal true, entry["en"]["published"]
      assert_equal false, entry["pt-BR"]["published"]
      assert_equal %w[ en pt-BR ], back["locales"].sort
    end
  end

  test "unknown format raises" do
    assert_raises(Snapshot::FormatError) { Snapshot.dump(SAMPLE, format: "yaml") }
  end

  test "invalid JSON body raises a FormatError" do
    assert_raises(Snapshot::FormatError) { Snapshot.load("{not json", format: "json") }
  end
end
