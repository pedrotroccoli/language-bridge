# Per-project upload rules: the effective max size and allowed import formats,
# inheriting the workspace defaults unless the project overrides them.
module Project::Uploads
  extend ActiveSupport::Concern

  included do
    validate :upload_allowed_formats_subset
  end

  def effective_upload_max_bytes
    return Setting.current.upload_max_bytes unless upload_override

    upload_max_bytes || Setting.current.upload_max_bytes
  end

  def effective_upload_allowed_formats
    return Setting.current.upload_allowed_formats unless upload_override

    upload_allowed_formats.presence || Setting.current.upload_allowed_formats
  end

  private
    # When overriding, a project's allowed formats can't exceed the importable set.
    def upload_allowed_formats_subset
      return unless upload_override && upload_allowed_formats.present?

      unknown = upload_allowed_formats - Snapshot::FORMATS
      errors.add(:upload_allowed_formats, "has unknown formats: #{unknown.join(', ')}") if unknown.any?
    end
end
