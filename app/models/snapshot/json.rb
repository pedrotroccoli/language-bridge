module Snapshot
  # Lossless JSON — the native snapshot shape.
  module Json
    CONTENT_TYPE = "application/json".freeze

    def self.dump(snapshot)
      JSON.pretty_generate(snapshot)
    end

    def self.load(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise Snapshot::FormatError, "Invalid JSON: #{e.message}"
    end
  end
end
