# Set a storage connection as the workspace default.
class StorageConnections::DefaultsController < ApplicationController
  before_action :require_admin

  def create
    StorageConnection.find(params[:storage_connection_id]).update!(is_default: true)
    redirect_to workspace_path, notice: "Default storage updated."
  end
end
