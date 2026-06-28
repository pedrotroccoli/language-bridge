class Projects::SettingsController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_administer_project

  def show
    @locales = @project.locales.alphabetically
    @namespaces = @project.namespaces.alphabetically
  end
end
