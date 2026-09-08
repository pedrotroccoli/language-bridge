# Shared helpers for the `lb login` browser hand-off: both approving and
# rejecting bounce the browser back to the loopback server the CLI listens on.
module Cli::Loopback
  private
    # Only ever redirect to a loopback address the CLI itself listens on — never
    # an arbitrary external host (which would leak the code).
    def loopback?(uri)
      parsed = URI.parse(uri)
      parsed.scheme == "http" && [ "127.0.0.1", "localhost", "::1" ].include?(parsed.host)
    rescue URI::InvalidURIError
      false
    end

    def callback_url(uri, **params)
      parsed = URI.parse(uri)
      query = URI.decode_www_form(parsed.query || "")
      params.each { |key, value| query << [ key.to_s, value ] if value.present? }
      parsed.query = URI.encode_www_form(query)
      parsed.to_s
    end
end
