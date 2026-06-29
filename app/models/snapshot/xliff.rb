require "rexml/document"

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

      out = +%(<?xml version="1.0" encoding="UTF-8"?>\n<xliff version="1.2">\n)
      namespaces.each do |namespace, keys|
        locales.each do |locale|
          out << %(  <file original="#{esc(namespace)}" source-language="#{esc(source)}" target-language="#{esc(locale)}" datatype="plaintext">\n    <body>\n)
          keys.each do |key, entries|
            entry = entries[locale]
            next unless entry

            source_value = entries.dig(source, "value").to_s
            state = entry["published"] ? "final" : "needs-translation"
            out << %(      <trans-unit id="#{esc(key)}" resname="#{esc(key)}">\n)
            out << %(        <source>#{esc(source_value)}</source>\n)
            out << %(        <target state="#{state}">#{esc(entry["value"].to_s)}</target>\n)
            out << %(      </trans-unit>\n)
          end
          out << %(    </body>\n  </file>\n)
        end
      end
      out << "</xliff>\n"
      out
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

    def self.esc(string)
      REXML::Text.normalize(string.to_s)
    end
  end
end
