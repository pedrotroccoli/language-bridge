# Transport compression for delivery artifacts (issue #95). The compiled JSON is
# stored already-compressed so /cdn responses can stream the bytes as-is under a
# Content-Encoding header — transparent to clients that decompress (i18next,
# browsers, most HTTP libs).
#
# gzip is universal and always available. brotli is OPTIONAL: it only kicks in
# when the `brotli` gem is installed. If a workspace selects "br" without the
# gem, we transparently fall back to gzip rather than ship uncompressed.
module DeliveryCompression
  MODES = %w[ none gzip br ].freeze

  module_function

  def brotli_available?
    defined?(::Brotli)
  end

  # Resolve a requested mode against what's actually producible. "br" degrades to
  # "gzip" when the gem is missing; anything unrecognized degrades to "none".
  def effective_mode(mode)
    case mode.to_s
    when "br"   then brotli_available? ? "br" : "gzip"
    when "gzip" then "gzip"
    else "none"
    end
  end

  # Compress json for the given mode. Returns [encoding, bytes] where encoding is
  # the Content-Encoding token ("gzip"/"br") or nil when stored uncompressed.
  def compress(json, mode)
    case effective_mode(mode)
    when "br"   then [ "br", ::Brotli.deflate(json) ]
    when "gzip" then [ "gzip", ActiveSupport::Gzip.compress(json) ]
    else [ nil, json ]
    end
  end

  # Inverse of #compress, for the rare client that doesn't accept the stored
  # encoding (we decode on the fly and serve raw JSON).
  def decompress(bytes, encoding)
    case encoding
    when "br"   then ::Brotli.inflate(bytes)
    when "gzip" then ActiveSupport::Gzip.decompress(bytes)
    else bytes
    end
  end
end
