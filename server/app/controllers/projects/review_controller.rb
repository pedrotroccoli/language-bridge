# Entry point for `lb review`: lands the reviewer in the normal editor, filtered
# to the draft translations a CLI push wrote (?session=). Picks the namespace of
# the first matching draft so the editor opens where the work is, then the built-in
# status/session filters take over. No bespoke screen — same editor as always.
class Projects::ReviewController < ApplicationController
  include ProjectScoped

  def show
    session = params[:session].to_s.presence
    namespace = namespace_to_open(session)
    return redirect_to project_path(@project), alert: "No namespaces yet." if namespace.nil?

    redirect_to project_namespace_path(@project, namespace, session: session, status: "drafts")
  end

  private
    # The namespace of the first draft for this session, falling back to the first
    # namespace so the editor always has somewhere to land.
    def namespace_to_open(session)
      drafts = @project.translations.drafts
      drafts = drafts.in_session(session) if session
      namespace_id = drafts.joins(translation_key: :namespace).order("namespaces.name").limit(1).pick("translation_keys.namespace_id")

      @project.namespaces.find_by(id: namespace_id) || @project.namespaces.alphabetically.first
    end
end
