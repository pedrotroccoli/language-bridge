class StorageConnectionsController < ApplicationController
  before_action :require_admin
  before_action :set_connection, only: %i[ update destroy ]

  def create
    connection = StorageConnection.new(connection_params)
    connection.is_default = true if StorageConnection.none? # first one is the default
    if connection.save
      redirect_to workspace_path, notice: "Storage connection added."
    else
      redirect_to workspace_path, alert: connection.errors.full_messages.to_sentence
    end
  end

  def update
    # A blank secret on edit means "keep the stored one" — don't overwrite.
    attrs = connection_params
    attrs = attrs.except(:secret_access_key) if attrs[:secret_access_key].blank?
    if @connection.update(attrs)
      redirect_to workspace_path, notice: "Storage connection updated."
    else
      redirect_to workspace_path, alert: @connection.errors.full_messages.to_sentence
    end
  end

  def destroy
    @connection.destroy
    redirect_to workspace_path, notice: "Storage connection removed."
  end

  # Verifies (possibly unsaved) connection params by round-tripping a probe object.
  # Responds JSON for the modal's inline "Test connection" button.
  def test
    connection = StorageConnection.new(connection_params)
    result = StorageConnection::Tester.call(connection)
    render json: { ok: result.ok?, message: result.message }
  end

  private
    def set_connection
      @connection = StorageConnection.find(params[:id])
    end

    def connection_params
      params.expect(storage_connection: %i[
        name service bucket region endpoint prefix inherit_credentials access_key_id secret_access_key
      ])
    end
end
