require "csv"

module Snapshot
  # Flat CSV with one row per (namespace, key, locale). Lossless: published state
  # rides along in its own column. Header order is stable for diff-friendliness.
  module Csv
    CONTENT_TYPE = "text/csv".freeze
    HEADERS = %w[ namespace key locale value published ].freeze

    def self.dump(snapshot)
      ::CSV.generate do |csv|
        csv << HEADERS
        (snapshot["namespaces"] || {}).each do |namespace, keys|
          keys.each do |key, entries|
            entries.each do |locale, entry|
              csv << [ namespace, key, locale, entry["value"], entry["published"] ]
            end
          end
        end
      end
    end

    def self.load(body)
      namespaces = Hash.new { |h, ns| h[ns] = Hash.new { |k, key| k[key] = {} } }
      locales = []

      ::CSV.parse(body, headers: true) do |row|
        ns, key, locale = row["namespace"], row["key"], row["locale"]
        next if ns.blank? || key.blank? || locale.blank?

        locales << locale
        namespaces[ns][key][locale] = {
          "value"     => row["value"].to_s,
          "published" => ActiveModel::Type::Boolean.new.cast(row["published"])
        }
      end

      { "version" => TranslationSnapshot::VERSION, "locales" => locales.uniq, "namespaces" => deep_to_h(namespaces) }
    rescue ::CSV::MalformedCSVError => e
      raise Snapshot::FormatError, "Invalid CSV: #{e.message}"
    end

    # Convert the default-block hashes into plain hashes for restore.
    def self.deep_to_h(hash)
      hash.transform_values { |v| v.is_a?(Hash) ? deep_to_h(v) : v }
    end
    private_class_method :deep_to_h
  end
end
