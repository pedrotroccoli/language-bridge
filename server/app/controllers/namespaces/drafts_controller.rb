# Discards every unpublished draft in a namespace ("Discard all"). Drafts are
# unpublished, so they're absent from the materialized delivery artifacts —
# deleting them reverts the editor to the published state without touching
# production.
class Namespaces::DraftsController < ApplicationController
  include ProjectScoped

  before_action :set_namespace
  before_action :ensure_can_edit_translations

  def destroy
    drafts = Translation.drafts_in_namespace(@namespace)
    count = drafts.count
    drafts.destroy_all

    notice = count.zero? ? "No drafts to discard." : "Discarded #{count} #{"draft".pluralize(count)}."
    redirect_to project_namespace_path(@project, @namespace), notice: notice, status: :see_other
  end

  private
    def set_namespace
      @namespace = @project.namespaces.find_by!(name: params[:namespace_id])
    end
end
