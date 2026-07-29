# A project's upload rules: which storage connection it writes to, the path
# prefix, and whether it overrides the workspace upload defaults (max size,
# allowed import formats).
class Projects::UploadSettingsController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_administer_project

  def update
    if @project.update(upload_params)
      redirect_to project_settings_path(@project), notice: "Upload settings saved."
    else
      redirect_to project_settings_path(@project), alert: @project.errors.full_messages.to_sentence
    end
  end

  private
    def upload_params
      params.expect(project: [
        :storage_connection_id, :upload_path, :upload_override, :upload_max_bytes,
        { upload_allowed_formats: [] }
      ]).tap do |attrs|
        # Blank select → workspace default (nil), not an empty string FK.
        attrs[:storage_connection_id] = attrs[:storage_connection_id].presence
      end
    end
end
