# Downloads a namespace's translations (all locales) in JSON / CSV / XLIFF.
class Namespaces::ExportsController < ApplicationController
  include ProjectScoped

  before_action :set_namespace

  def show
    format = params[:as].to_s.presence_in(Snapshot::FORMATS) || "json"
    body, content_type, ext = Snapshot.dump(namespace_snapshot, format: format)
    send_data body, filename: "#{@project.slug}-#{@namespace.name}.#{ext}", type: content_type
  end

  private
    def set_namespace
      @namespace = @project.namespaces.find_by!(name: params[:namespace_id])
    end

    # Canonical snapshot hash scoped to this one namespace, reusing the Snapshot
    # serializers (every key, locale, value and published flag).
    def namespace_snapshot
      keys = {}
      @namespace.translation_keys.order(:key).includes(translations: %i[ locale publication ]).each do |key|
        entries = {}
        key.translations.each do |translation|
          entries[translation.locale.code] = { "value" => translation.value, "published" => translation.published? }
        end
        keys[key.key] = entries
      end

      {
        "version" => TranslationSnapshot::VERSION,
        "locales" => @project.locales.order(:code).pluck(:code),
        "namespaces" => { @namespace.name => keys }
      }
    end
end
