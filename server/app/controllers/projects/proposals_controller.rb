# Human review inbox for AI/CLI translation proposals: list pending proposals
# and reject (destroy) them. Accepting lives in Proposals::AcceptancesController.
class Projects::ProposalsController < ApplicationController
  include ProjectScoped

  before_action :ensure_can_edit_translations, only: :destroy

  def index
    @proposals = @project.translation_proposals.recent.includes(:namespace, :locale, :author)
  end

  # Reject a proposal.
  def destroy
    @project.translation_proposals.find(params[:id]).reject(by: current_user)
    redirect_to project_proposals_path(@project), notice: "Proposal rejected."
  end
end
