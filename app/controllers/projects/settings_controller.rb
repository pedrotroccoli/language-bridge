class Projects::SettingsController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_administer_project

  def show
    @locales = @project.locales.alphabetically
    @namespaces = @project.namespaces.alphabetically
    @api_tokens = @project.api_tokens.active.order(created_at: :desc)
  end
end
