require "test_helper"

class DeliveryCompressionTest < ActiveSupport::TestCase
  test "gzip compresses and round-trips" do
    json = { greeting: "Hello" }.to_json
    encoding, bytes = DeliveryCompression.compress(json, "gzip")

    assert_equal "gzip", encoding
    assert_not_equal json, bytes
    assert_equal json, DeliveryCompression.decompress(bytes, encoding)
  end

  test "none stores plain bytes with no encoding" do
    json = { greeting: "Hello" }.to_json
    encoding, bytes = DeliveryCompression.compress(json, "none")

    assert_nil encoding
    assert_equal json, bytes
    assert_equal json, DeliveryCompression.decompress(bytes, encoding)
  end

  test "brotli falls back to gzip when the gem is unavailable" do
    skip "brotli gem installed" if DeliveryCompression.brotli_available?

    assert_equal "gzip", DeliveryCompression.effective_mode("br")
    encoding, = DeliveryCompression.compress("{}", "br")
    assert_equal "gzip", encoding
  end

  test "unknown mode degrades to none" do
    assert_equal "none", DeliveryCompression.effective_mode("zstd")
  end
end
