# Re-materialize every published (namespace, locale) to the project's current
# storage connection — a manual "sync everything to the cloud bucket" action.
class Projects::DeliverySyncController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_administer_project

  def create
    count = @project.rematerialize_delivery!
    redirect_to project_settings_path(@project), notice: "Synced #{count} #{"file".pluralize(count)} to storage."
  end
end
