# Promote a reported missing key into a real translation key.
class Projects::Missing::PromotionsController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_edit_translations

  def create
    report = @project.missing_key_reports.find(params[:missing_id])
    translation_key = report.promote!(author: current_user)
    redirect_to project_missing_index_path(@project), notice: "Created key #{translation_key.key}."
  end
end
