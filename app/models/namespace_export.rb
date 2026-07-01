require "csv"
require "zip"

# Data-only export of a namespace: clean translation values per locale, with NO
# Language Bridge metadata (no version, no published flags). The inverse of
# TranslationImport: a file produced here re-imports losslessly, and the JSON
# shape is the nested object an i18next client (or locize) consumes directly.
#
# This is deliberately distinct from Snapshot / TranslationSnapshot, which is the
# full-fidelity *backup* format (carries version + published state for restore).
# Use NamespaceExport for interop, Snapshot for backups.
#
#   * JSON — nested object, one file per locale ("home.title" -> {home:{title:..}})
#   * CSV  — flat "key,value" rows, one file per locale
#
# A single locale downloads as one file; multiple locales are bundled into a ZIP
# of "<locale>.<ext>" entries (the standard i18next per-language layout).
class NamespaceExport
  FORMATS = %w[ json csv ].freeze

  File = Struct.new(:body, :content_type, :filename, keyword_init: true)

  class Error < StandardError; end

  # locales: the Locale records to export (defaults to all project locales).
  # include_drafts: when true (default) every non-empty value is exported;
  # when false only published values are, matching live delivery.
  def initialize(namespace, locales: nil, include_drafts: true)
    @namespace = namespace
    @locales = locales || namespace.project.locales.order(:code).to_a
    @include_drafts = include_drafts
  end

  # Returns a File (body, content_type, filename) for the given format. One file
  # per locale collapses to a single download; many locales zip together.
  def download(format)
    format = format.to_s
    raise Error, "Unsupported data format #{format.inspect}" unless FORMATS.include?(format)
    raise Error, "No locales to export" if @locales.empty?

    files = @locales.map { |locale| file_for(locale, format) }
    files.one? ? single(files.first) : zip(files, format)
  end

  # Serialized body for one locale in the given format, without any packaging —
  # lets a project-wide exporter reuse per-namespace rendering under its own paths.
  def content(locale, format)
    format = format.to_s
    raise Error, "Unsupported data format #{format.inspect}" unless FORMATS.include?(format)

    file_for(locale, format).body
  end

  private
    def prefix
      "#{@namespace.project.slug}-#{@namespace.name}"
    end

    # One locale, one file — prefix it with project/namespace for a friendly name.
    def single(file)
      File.new(body: file.body, content_type: file.content_type, filename: "#{prefix}-#{file.filename}")
    end

    def zip(files, format)
      buffer = Zip::OutputStream.write_buffer do |zos|
        files.each do |file|
          zos.put_next_entry(file.filename)
          zos.write(file.body)
        end
      end
      File.new(body: buffer.string, content_type: "application/zip", filename: "#{prefix}-#{format}.zip")
    end

    def file_for(locale, format)
      values = flat_values(locale)
      case format
      when "json" then File.new(body: JSON.pretty_generate(nest(values)), content_type: "application/json", filename: "#{locale.code}.json")
      when "csv"  then File.new(body: csv(values), content_type: "text/csv", filename: "#{locale.code}.csv")
      end
    end

    # { "dotted.key" => value } for one locale, skipping empty values. Includes
    # drafts unless include_drafts is false. Keys sorted for stable diffs.
    def flat_values(locale)
      scope = Translation
        .where(locale: locale)
        .joins(:translation_key)
        .where(translation_keys: { namespace_id: @namespace.id })
        .where.not(value: [ nil, "" ])
        .includes(:translation_key)
      scope = scope.published unless @include_drafts

      scope.each_with_object({}) { |t, h| h[t.translation_key.key] = t.value }
           .sort.to_h
    end

    # Expand dotted keys into nested objects (inverse of TranslationImport#flatten).
    def nest(values)
      values.each_with_object({}) do |(key, value), tree|
        insert(tree, key.split("."), value)
      end
    end

    def insert(tree, segments, value)
      leaf = segments.pop
      node = segments.reduce(tree) do |hash, segment|
        hash[segment] = {} unless hash[segment].is_a?(Hash)
        hash[segment]
      end
      node[leaf] = value
    end

    def csv(values)
      ::CSV.generate do |out|
        out << %w[ key value ]
        values.each { |key, value| out << [ key, value ] }
      end
    end
end
