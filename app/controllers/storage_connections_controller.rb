class StorageConnectionsController < ApplicationController
  before_action :require_admin

  def create
    connection = StorageConnection.new(connection_params)
    connection.is_default = true if StorageConnection.none? # first one is the default
    if connection.save
      redirect_to workspace_path, notice: "Storage connection added."
    else
      redirect_to workspace_path, alert: connection.errors.full_messages.to_sentence
    end
  end

  def destroy
    StorageConnection.find(params[:id]).destroy
    redirect_to workspace_path, notice: "Storage connection removed."
  end

  private
    def connection_params
      params.expect(storage_connection: %i[ name service_name bucket region ])
    end
end
