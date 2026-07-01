# Transport compression for delivery artifacts. The compiled JSON is
# stored already-compressed so /cdn responses can stream the bytes as-is under a
# Content-Encoding header — transparent to clients that decompress (i18next,
# browsers, most HTTP libs).
#
# gzip is universal (stdlib). brotli ships via the `brotli` gem (a dependency),
# so it's normally available; the guard below stays defensive so a build without
# the native extension degrades to gzip instead of crashing.
module DeliveryCompression
  MODES = %w[ none gzip br ].freeze

  module_function

  def brotli_available?
    !!defined?(::Brotli)
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

  # Returns [encoding, bytes]; encoding is the Content-Encoding token or nil.
  def compress(json, mode)
    case effective_mode(mode)
    when "br"   then [ "br", ::Brotli.deflate(json) ]
    when "gzip" then [ "gzip", ActiveSupport::Gzip.compress(json) ]
    else [ nil, json ]
    end
  end

  def decompress(bytes, encoding)
    case encoding
    when "br"   then ::Brotli.inflate(bytes)
    when "gzip" then ActiveSupport::Gzip.decompress(bytes)
    else bytes
    end
  end
end
