# Snapshot serialization formats. A "snapshot" is the canonical Hash produced by
# TranslationSnapshot.build — every namespace, key, locale, value and published
# flag. Each format can `dump` that Hash to a String and `load` it back, so a
# backup can be written (and restored) in JSON, CSV or XLIFF.
module Snapshot
  FORMATS = %w[ json csv xliff ].freeze

  class FormatError < StandardError; end

  def self.for(format)
    case format.to_s
    when "json"  then Snapshot::Json
    when "csv"   then Snapshot::Csv
    when "xliff" then Snapshot::Xliff
    else raise FormatError, "unsupported format #{format.inspect}"
    end
  end

  # Returns [body_string, content_type, extension] for a built snapshot hash.
  def self.dump(snapshot, format:)
    fmt = self.for(format)
    [ fmt.dump(snapshot.deep_stringify_keys), fmt::CONTENT_TYPE, format.to_s ]
  end

  # Parses a serialized backup body back into the canonical snapshot hash.
  def self.load(body, format:)
    self.for(format).load(body)
  end
end
