# Full-fidelity JSON snapshot of a project's translations — every namespace, key,
# locale, value and published state. Used by the cloud backup (Project::Backup):
# `build` serializes, `restore` re-imports. Serialization is lossless enough to
# reconstruct the translation set; restore is an idempotent upsert (it never
# deletes keys/translations absent from the snapshot).
class TranslationSnapshot
  VERSION = 1

  class FormatError < StandardError; end

  # Pass namespace: to scope the snapshot to a single namespace (e.g. a namespace
  # export); omit it for the whole project.
  def self.build(project, include_drafts: true, namespace: nil)
    new(project, include_drafts:, namespace:).build
  end

  def initialize(project, include_drafts: true, namespace: nil)
    @project = project
    @include_drafts = include_drafts
    @namespace = namespace
  end

  def build
    {
      version: VERSION,
      created_at: Time.current.utc.iso8601,
      project: { slug: @project.slug, name: @project.name },
      locales: @project.locales.order(:code).pluck(:code),
      namespaces: namespaces_hash
    }
  end

  # Re-import a snapshot hash into the project. Returns the count of translations
  # written. Creates any missing locales/namespaces/keys.
  def self.restore(project, data)
    raise FormatError, "unsupported snapshot version #{data["version"].inspect}" unless data.is_a?(Hash) && data["version"] == VERSION

    written = 0
    locales = {}

    ActiveRecord::Base.transaction do
      Array(data["locales"]).each { |code| locales[code] = project.locales.find_or_create_by!(code: code) }

      (data["namespaces"] || {}).each do |namespace_name, keys|
        namespace = project.namespaces.find_or_create_by!(name: namespace_name)

        keys.each do |key_path, entries|
          translation_key = project.translation_keys.find_or_create_by!(namespace: namespace, key: key_path)

          entries.each do |code, entry|
            locale = (locales[code] ||= project.locales.find_or_create_by!(code: code))
            translation = translation_key.set_translation(locale: locale, value: entry["value"])
            translation.publish if entry["published"] && !translation.published?
            written += 1
          end
        end
      end
    end

    written
  end

  private
    def namespaces_hash
      result = {}
      scope = @project.namespaces.order(:name).includes(translation_keys: { translations: %i[ locale publication ] })
      scope = scope.where(id: @namespace.id) if @namespace
      scope.each do |namespace|
        keys = {}
        namespace.translation_keys.sort_by(&:key).each do |translation_key|
          entries = {}
          translation_key.translations.each do |translation|
            next if !@include_drafts && !translation.published?

            entries[translation.locale.code] = { value: translation.value, published: translation.published? }
          end
          keys[translation_key.key] = entries
        end
        result[namespace.name] = keys
      end
      result
    end
end
