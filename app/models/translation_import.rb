require "csv"
require "rexml/document"

# Imports a file of translations for a single locale into a namespace. Accepts
# JSON (nested objects flatten to dotted keys), CSV (key,value rows) or XLIFF
# (trans-unit id/resname → target). Non-string leaves are stringified. Existing
# values are overwritten (Translation snapshots a Version on change). Missing
# keys are created.
class TranslationImport
  FORMATS = %w[ json csv xliff ].freeze

  Result = Struct.new(:keys_created, :translations_written, keyword_init: true) do
    def summary(locale)
      "Imported #{translations_written} #{"translation".pluralize(translations_written)} " \
        "into #{locale.code} (#{keys_created} new #{"key".pluralize(keys_created)})."
    end
  end

  class Error < StandardError; end

  # Best-effort format detection from the uploaded filename's extension.
  def self.format_from_filename(filename)
    ext = File.extname(filename.to_s).delete(".").downcase
    ext = "xliff" if ext == "xlf"
    FORMATS.include?(ext) ? ext : "json"
  end

  def initialize(namespace:, locale:, author:, format: "json")
    @namespace = namespace
    @locale = locale
    @author = author
    @format = format.to_s
    raise Error, "Unsupported format #{@format.inspect}" unless FORMATS.include?(@format)
  end

  def import(content)
    entries = parse(content)
    raise Error, "File contains no translations" if entries.empty?

    keys_created = 0
    written = 0

    ActiveRecord::Base.transaction do
      entries.each do |key, value|
        translation_key = @namespace.translation_keys.find_by(key: key)
        unless translation_key
          translation_key = @namespace.translation_keys.create!(project: @namespace.project, key: key)
          keys_created += 1
        end

        translation = Translation.find_or_initialize_by(translation_key: translation_key, locale: @locale)
        translation.assign_attributes(value: value, author: @author)
        translation.save!
        written += 1
      end

      @namespace.project.track_event("translations_imported", creator: @author, metadata: {
        namespace: @namespace.name, locale: @locale.code, format: @format,
        keys_created: keys_created, translations_written: written
      })
    end

    Result.new(keys_created: keys_created, translations_written: written)
  end

  private
    # Returns a flat { "dotted.key" => "value" } hash regardless of format.
    def parse(content)
      case @format
      when "json"  then parse_json(content)
      when "csv"   then parse_csv(content)
      when "xliff" then parse_xliff(content)
      end
    end

    def parse_json(content)
      data = JSON.parse(content)
      raise Error, "Expected a JSON object of key/value pairs" unless data.is_a?(Hash)
      flatten(data)
    rescue JSON::ParserError => e
      raise Error, "Invalid JSON: #{e.message}"
    end

    def parse_csv(content)
      rows = CSV.parse(content, headers: true)
      key_col   = rows.headers.include?("key") ? "key" : rows.headers.first
      value_col = rows.headers.include?("value") ? "value" : rows.headers[1]
      raise Error, "CSV needs a key and a value column" if key_col.nil? || value_col.nil?

      rows.each_with_object({}) do |row, acc|
        key = row[key_col].to_s.strip
        acc[key] = row[value_col].to_s unless key.empty?
      end
    rescue CSV::MalformedCSVError => e
      raise Error, "Invalid CSV: #{e.message}"
    end

    def parse_xliff(content)
      doc = REXML::Document.new(content)
      acc = {}
      doc.elements.each("xliff/file/body/trans-unit") do |unit|
        key = (unit.attributes["resname"] || unit.attributes["id"]).to_s
        next if key.empty?

        acc[key] = (unit.elements["target"] || unit.elements["source"])&.text.to_s
      end
      acc
    rescue REXML::ParseException => e
      raise Error, "Invalid XLIFF: #{e.message}"
    end

    def flatten(hash, prefix = nil, acc = {})
      hash.each do |key, value|
        dotted = prefix ? "#{prefix}.#{key}" : key.to_s
        if value.is_a?(Hash)
          flatten(value, dotted, acc)
        else
          acc[dotted] = stringify(value)
        end
      end
      acc
    end

    def stringify(value)
      case value
      when String      then value
      when nil         then ""
      when Array, Hash then JSON.generate(value)
      else value.to_s
      end
    end
end
