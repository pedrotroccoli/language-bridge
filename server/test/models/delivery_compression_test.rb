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

  test "brotli compresses and round-trips" do
    assert DeliveryCompression.brotli_available?, "brotli gem should be a dependency"

    json = { greeting: "Hello" }.to_json
    encoding, bytes = DeliveryCompression.compress(json, "br")

    assert_equal "br", encoding
    assert_not_equal json, bytes
    assert_equal json, DeliveryCompression.decompress(bytes, encoding)
  end

  test "unknown mode degrades to none" do
    assert_equal "none", DeliveryCompression.effective_mode("zstd")
  end
end
