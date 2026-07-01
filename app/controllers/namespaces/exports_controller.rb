# Downloads a namespace's translations. Two modes:
#   * default ("data") — clean, metadata-free values a client (i18next/locize) or
#     our own import consumes: nested JSON / flat CSV, one file per locale (zipped
#     when there's more than one). See NamespaceExport.
#   * mode=backup — full-fidelity Snapshot (version + published flags) in JSON /
#     CSV / XLIFF, for our own backup & restore.
class Namespaces::ExportsController < ApplicationController
  include ProjectScoped

  before_action :set_namespace

  def show
    params[:mode] == "backup" ? send_backup : send_data_export
  end

  private
    # Metadata-free, round-trippable, interop-friendly (locize/i18next).
    def send_data_export
      format = params[:as].to_s.presence_in(NamespaceExport::FORMATS) || "json"
      file = NamespaceExport.new(@namespace, locales: selected_locales).download(format)
      send_data file.body, filename: file.filename, type: file.content_type
    rescue NamespaceExport::Error => e
      redirect_to project_namespace_path(@project, @namespace), alert: e.message, status: :see_other
    end

    # Full-fidelity Snapshot for backup/restore (carries our metadata).
    def send_backup
      format = params[:as].to_s.presence_in(Snapshot::FORMATS) || "json"
      body, content_type, ext = Snapshot.dump(namespace_snapshot, format: format)
      send_data body, filename: "#{@project.slug}-#{@namespace.name}.#{ext}", type: content_type
    end

    # Optional ?locale= narrows a data export to one language (ideal for locize's
    # per-language import); absent, every project locale is exported.
    def selected_locales
      return nil if params[:locale].blank?

      @project.locales.where(code: params[:locale]).to_a
    end

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
