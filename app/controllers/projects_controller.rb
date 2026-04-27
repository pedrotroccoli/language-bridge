class ProjectsController < ApplicationController
  before_action :set_project,                    only: %i[ show edit update destroy ]
  before_action :ensure_can_administer_project,  only: %i[ new create edit update destroy ]

  def index
    @projects = current_user.accessible_projects.alphabetically
    fresh_when etag: [ @projects, current_user ]
  end

  def show
    @namespaces = @project.namespaces.alphabetically
    @new_namespace = @project.namespaces.build(name: flash[:invalid_namespace_name])
  end

  def new
    @project = Project.new
  end

  def edit
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy!
    redirect_to projects_path, notice: "Project deleted."
  end

  private
    def set_project
      @project = current_user.accessible_projects.find_by!(slug: params[:id])
    end

    def project_params
      params.expect(project: %i[ name ])
    end

    def ensure_can_administer_project
      head :forbidden unless current_user&.can_administer_project?(@project)
    end
end
