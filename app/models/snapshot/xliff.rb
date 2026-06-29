require "rexml/document"
require "builder"

module Snapshot
  # XLIFF 1.2. One <file> per (namespace, target locale): `original` carries the
  # namespace, `target-language` the locale, each <trans-unit id> the key. The
  # <target> state encodes published ("final") vs draft ("needs-translation").
  # The source language is the snapshot's first locale.
  module Xliff
    CONTENT_TYPE = "application/x-xliff+xml".freeze

    def self.dump(snapshot)
      locales = Array(snapshot["locales"])
      source = locales.first || "en"
      namespaces = snapshot["namespaces"] || {}

      xml = Builder::XmlMarkup.new(indent: 2)
      xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
      xml.xliff(version: "1.2") do
        namespaces.each do |namespace, keys|
          locales.each do |locale|
            xml.file(original: namespace, "source-language": source, "target-language": locale, datatype: "plaintext") do
              xml.body do
                keys.each do |key, entries|
                  entry = entries[locale] or next
                  state = entry["published"] ? "final" : "needs-translation"
                  xml.tag!("trans-unit", id: key, resname: key) do
                    xml.source(entries.dig(source, "value").to_s)
                    xml.target(entry["value"].to_s, state: state)
                  end
                end
              end
            end
          end
        end
      end
    end

    def self.load(body)
      doc = REXML::Document.new(body)
      namespaces = Hash.new { |h, ns| h[ns] = {} }
      locales = []

      doc.elements.each("xliff/file") do |file|
        namespace = file.attributes["original"].to_s
        locale = file.attributes["target-language"].to_s
        next if namespace.blank? || locale.blank?

        locales << locale
        file.elements.each("body/trans-unit") do |unit|
          key = (unit.attributes["resname"] || unit.attributes["id"]).to_s
          next if key.blank?

          target = unit.elements["target"]
          namespaces[namespace][key] ||= {}
          namespaces[namespace][key][locale] = {
            "value"     => target&.text.to_s,
            "published" => target&.attributes&.[]("state") == "final"
          }
        end
      end

      { "version" => TranslationSnapshot::VERSION, "locales" => locales.uniq, "namespaces" => namespaces.transform_values(&:itself) }
    rescue REXML::ParseException => e
      raise Snapshot::FormatError, "Invalid XLIFF: #{e.message}"
    end
  end
end
