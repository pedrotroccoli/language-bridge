# The CLI's loopback callback in the `lb login` hand-off: the browser is only
# ever sent back to a local address the CLI itself listens on — never an
# arbitrary host, which would leak the one-time code — and both halves of the
# flow redirect through it: approval with a code, rejection with
# error=access_denied.
class Cli::Callback
  def initialize(uri)
    @uri = uri.to_s
  end

  def loopback?
    parsed = URI.parse(@uri)
    parsed.scheme == "http" && [ "127.0.0.1", "localhost", "::1" ].include?(parsed.host)
  rescue URI::InvalidURIError
    false
  end

  def url(**params)
    parsed = URI.parse(@uri)
    query = URI.decode_www_form(parsed.query || "")
    params.each { |key, value| query << [ key.to_s, value ] if value.present? }
    parsed.query = URI.encode_www_form(query)
    parsed.to_s
  end
end
