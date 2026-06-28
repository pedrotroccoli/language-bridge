# Imports a JSON file of translations for a single locale into a namespace.
# Nested objects flatten to dotted keys ("home.title"); non-string leaves are
# stringified. Existing values are overwritten (Translation snapshots a Version
# on change). Missing keys are created.
class TranslationImport
  Result = Struct.new(:keys_created, :translations_written, keyword_init: true) do
    def summary(locale)
      "Imported #{translations_written} #{"translation".pluralize(translations_written)} " \
        "into #{locale.code} (#{keys_created} new #{"key".pluralize(keys_created)})."
    end
  end

  class Error < StandardError; end

  def initialize(namespace:, locale:, author:)
    @namespace = namespace
    @locale = locale
    @author = author
  end

  def import(json)
    data = parse(json)
    entries = flatten(data)
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
        namespace: @namespace.name, locale: @locale.code,
        keys_created: keys_created, translations_written: written
      })
    end

    Result.new(keys_created: keys_created, translations_written: written)
  end

  private
    def parse(json)
      data = JSON.parse(json)
      raise Error, "Expected a JSON object of key/value pairs" unless data.is_a?(Hash)
      data
    rescue JSON::ParserError => e
      raise Error, "Invalid JSON: #{e.message}"
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
      when String     then value
      when nil        then ""
      when Array, Hash then JSON.generate(value)
      else value.to_s
      end
    end
end
