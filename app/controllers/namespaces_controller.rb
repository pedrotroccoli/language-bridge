class NamespacesController < ApplicationController
  before_action :set_project
  before_action :set_namespace,                 only: %i[ update destroy ]
  before_action :ensure_can_administer_project, only: %i[ create update destroy ]

  def create
    @namespace = @project.namespaces.build(namespace_params)

    if @namespace.save
      redirect_to project_path(@project), notice: "Namespace created."
    else
      redirect_to project_path(@project, new_namespace: namespace_params[:name]),
                  alert: @namespace.errors.full_messages.to_sentence,
                  status: :see_other
    end
  end

  def update
    if @namespace.update(namespace_params)
      redirect_to project_path(@project), notice: "Namespace updated."
    else
      redirect_to project_path(@project),
                  alert: @namespace.errors.full_messages.to_sentence,
                  status: :see_other
    end
  end

  def destroy
    @namespace.destroy!
    redirect_to project_path(@project), notice: "Namespace deleted."
  end

  private
    def set_project
      @project = Project.find_by!(slug: params[:project_id])
    end

    def set_namespace
      @namespace = @project.namespaces.find_by!(name: params[:id])
    end

    def namespace_params
      params.expect(namespace: %i[ name ])
    end

    def ensure_can_administer_project
      head :forbidden unless current_user&.can_administer_project?(@project)
    end
end
