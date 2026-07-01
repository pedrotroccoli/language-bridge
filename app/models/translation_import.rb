require "csv"
require "rexml/document"

# Imports a file of translations for a single locale into a namespace. Accepts
# JSON (nested objects flatten to dotted keys), CSV (key,value rows) or XLIFF
# (trans-unit id/resname → target). Non-string leaves are stringified. Existing
# values are overwritten; missing keys are created.
#
# Persistence is bulk (compass "Batch SQL Over Loops"): keys and translations
# are inserted/upserted in batches of #batch_size rather than one save! per
# entry, so a multi-thousand-key file imports in a handful of queries instead of
# ~4 per row. Because upsert_all/insert_all bypass model callbacks, this class
# reproduces their side effects explicitly:
#   * Translation::Version — old values snapshotted via insert_all before upsert.
#   * counter caches — recomputed set-based once at the end (update_all).
#   * value-change invalidation — stale publications/reviews/approvals discarded
#     once at the end, and the (namespace, locale) artifact rebuilt if any
#     published content went stale.
class TranslationImport
  FORMATS = %w[ json csv xliff ].freeze

  # Batch size for bulk insert/upsert. Configurable via ENV; overridable per
  # import via the batch_size: kwarg (e.g. tests, future per-project tuning).
  DEFAULT_BATCH_SIZE = Integer(ENV.fetch("IMPORT_BATCH_SIZE", 1000))

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

  def initialize(namespace:, locale:, author:, format: "json", batch_size: DEFAULT_BATCH_SIZE)
    @namespace = namespace
    @locale = locale
    @author = author
    @format = format.to_s
    @batch_size = batch_size.to_i.clamp(1, 10_000)
    raise Error, "Unsupported format #{@format.inspect}" unless FORMATS.include?(@format)
  end

  def import(content)
    entries = parse(content)
    raise Error, "File contains no translations" if entries.empty?

    keys_created = 0
    written = 0
    revalued_ids = [] # ids of existing translations whose value changed

    ActiveRecord::Base.transaction do
      entries.each_slice(@batch_size) do |slice|
        chunk = import_chunk(slice.to_h)
        keys_created += chunk[:keys_created]
        written += chunk[:written]
        revalued_ids.concat(chunk[:revalued_ids])
      end

      recompute_counters
      discarded = invalidate(revalued_ids)
      @rebuild_artifact = discarded.positive?

      @namespace.project.track_event("translations_imported", creator: @author, metadata: {
        namespace: @namespace.name, locale: @locale.code, format: @format,
        keys_created: keys_created, translations_written: written,
        publications_discarded: discarded
      })
    end

    # Rebuild the delivery artifact once, after commit — it uploads a blob, which
    # must not run inside the save transaction. Only needed when a re-imported
    # value invalidated already-published content.
    Translation::Artifact.rebuild(@namespace.id, @locale.id) if @rebuild_artifact

    Result.new(keys_created: keys_created, translations_written: written)
  end

  private
    # Upserts one slice of { "key" => "value" } entries. Returns counts plus the
    # ids of existing translations whose value actually changed (for end-of-run
    # version snapshots already written here, and invalidation done at the end).
    def import_chunk(chunk)
      key_ids = upsert_keys(chunk.keys)
      keys_created = chunk.keys.count { |k| key_ids[:created].include?(k) }

      existing = Translation
        .where(translation_key_id: key_ids[:map].values, locale_id: @locale.id)
        .pluck(:id, :translation_key_id, :value, :author_id)
        .index_by { |row| row[1] } # translation_key_id => [id, key_id, value, author_id]

      now = Time.current
      version_rows = []
      revalued_ids = []
      translation_rows = chunk.map do |key, value|
        kid = key_ids[:map][key]
        if (row = existing[kid]) && row[2] != value
          version_rows << { translation_id: row[0], value: row[2], author_id: row[3], created_at: now, updated_at: now }
          revalued_ids << row[0]
        end
        {
          translation_key_id: kid, locale_id: @locale.id, project_id: @namespace.project_id,
          value: value, author_id: @author&.id, created_at: now, updated_at: now
        }
      end

      Translation::Version.insert_all(version_rows) if version_rows.any?
      Translation.upsert_all(
        translation_rows,
        unique_by: %i[translation_key_id locale_id],
        update_only: %i[value author_id]
      )

      { keys_created: keys_created, written: translation_rows.size, revalued_ids: revalued_ids }
    end

    # Inserts any missing keys (skipping existing ones) and returns:
    #   { map: { "key" => uuid, ... }, created: ["key", ...] }
    def upsert_keys(keys)
      keys = keys.uniq
      map = @namespace.translation_keys.where(key: keys).pluck(:key, :id).to_h
      missing = keys - map.keys
      return { map: map, created: [] } if missing.empty?

      now = Time.current
      rows = missing.map { |k| { project_id: @namespace.project_id, namespace_id: @namespace.id, key: k, created_at: now, updated_at: now } }
      inserted = TranslationKey.insert_all(rows, unique_by: %i[project_id namespace_id key], returning: %w[id key])
      inserted.each { |r| map[r["key"]] = r["id"] }

      { map: map, created: inserted.map { |r| r["key"] } }
    end

    # Recompute the counter caches that upsert_all/insert_all bypassed, scoped to
    # what this import touched. Set-based (compass: update_all for side-effect-free
    # bulk) so it's a fixed handful of queries regardless of file size.
    def recompute_counters
      TranslationKey.where(namespace_id: @namespace.id)
        .update_all("translations_count = (SELECT COUNT(*) FROM translations WHERE translations.translation_key_id = translation_keys.id)")
      Locale.where(id: @locale.id)
        .update_all("translations_count = (SELECT COUNT(*) FROM translations WHERE translations.locale_id = locales.id)")
      Namespace.where(id: @namespace.id)
        .update_all("translation_keys_count = (SELECT COUNT(*) FROM translation_keys WHERE translation_keys.namespace_id = namespaces.id)")
      Project.where(id: @namespace.project_id)
        .update_all("translation_keys_count = (SELECT COUNT(*) FROM translation_keys WHERE translation_keys.project_id = projects.id)")
    end

    # Editing a value invalidates everything the old text earned: its publication
    # (back to draft) and any review/approval sign-off. The per-row model callback
    # is bypassed by upsert_all, so discard them in bulk here. Returns the number
    # of publications discarded (drives the one-shot artifact rebuild).
    def invalidate(ids)
      return 0 if ids.empty?

      ids.each_slice(@batch_size) do |slice|
        Translation::Review.where(translation_id: slice).delete_all
        Translation::Approval.where(translation_id: slice).delete_all
      end
      ids.each_slice(@batch_size).sum do |slice|
        Translation::Publication.where(translation_id: slice).delete_all
      end
    end

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
