# Accept a proposal: materialise its value as a draft translation (creating the
# key if new). Publishing stays a separate, human-authorised step.
class Projects::Proposals::AcceptancesController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_edit_translations

  def create
    proposal = @project.translation_proposals.find(params[:proposal_id])
    translation = proposal.accept(by: current_user)
    redirect_to project_proposals_path(@project), notice: "Accepted #{translation.translation_key.key} as a draft."
  end
end
