# Bulk-publishes every draft translation in a namespace ("Publish all").
class Namespaces::PublicationsController < ApplicationController
  include ProjectScoped

  before_action :set_namespace
  before_action :ensure_can_edit_translations

  def create
    drafts = Translation.drafts_in_namespace(@namespace)
    count = drafts.count
    Translation::Artifact.batch do
      drafts.find_each { |translation| translation.publish(by: current_user) }
    end

    notice = count.zero? ? "Nothing to publish." : "Published #{count} #{"translation".pluralize(count)}."
    redirect_to project_namespace_path(@project, @namespace), notice: notice, status: :see_other
  end

  private
    def set_namespace
      @namespace = @project.namespaces.find_by!(name: params[:namespace_id])
    end
end
