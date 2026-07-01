require "zip"

# Data-only export of an entire project: every namespace × locale rendered as
# clean, metadata-free files and bundled into one ZIP, laid out the way an
# i18next/locize client loads them — "<locale>/<namespace>.<ext>" (the same shape
# as the delivery loadPath "/cdn/:project/:locale/:namespace.json").
#
# Delegates per-namespace serialization to NamespaceExport (see it for format,
# draft and round-trip semantics). For a single namespace use NamespaceExport;
# for a full-fidelity backup of the project use TranslationSnapshot / Snapshot.
class ProjectExport
  FORMATS = NamespaceExport::FORMATS

  def initialize(project, include_drafts: true)
    @project = project
    @include_drafts = include_drafts
    @locales = project.locales.order(:code).to_a
    @namespaces = project.namespaces.order(:name).to_a
  end

  # Returns a NamespaceExport::File (body, content_type, filename): always a ZIP.
  # Namespaces with no values for a given locale are skipped (no empty entries).
  def download(format)
    format = format.to_s
    raise NamespaceExport::Error, "Unsupported data format #{format.inspect}" unless FORMATS.include?(format)
    raise NamespaceExport::Error, "Nothing to export" if @locales.empty? || @namespaces.empty?

    buffer = Zip::OutputStream.write_buffer do |zos|
      @namespaces.each do |namespace|
        exporter = NamespaceExport.new(namespace, locales: @locales, include_drafts: @include_drafts)
        @locales.each do |locale|
          body = exporter.content(locale, format)
          next if empty?(body, format)

          zos.put_next_entry("#{locale.code}/#{namespace.name}.#{format}")
          zos.write(body)
        end
      end
    end

    NamespaceExport::File.new(body: buffer.string, content_type: "application/zip", filename: "#{@project.slug}-#{format}.zip")
  end

  private
    # A namespace with no translated values for a locale renders to just an empty
    # object / a header-only CSV — skip it rather than ship a useless file.
    def empty?(body, format)
      case format
      when "json" then JSON.parse(body).empty?
      when "csv"  then body.strip.lines.size <= 1
      end
    end
end
