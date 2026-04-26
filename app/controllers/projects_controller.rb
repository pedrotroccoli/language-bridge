class ProjectsController < ApplicationController
  before_action :require_admin, only: %i[ new create edit update destroy ]
  before_action :set_project,   only: %i[ show edit update destroy ]

  def index
    @projects = Project.alphabetically
    fresh_when etag: [ @projects, current_user ]
  end

  def show
    fresh_when etag: [ @project, current_user ]
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
      @project = Project.find_by!(slug: params[:id])
    end

    def project_params
      params.expect(project: %i[ name ])
    end
end
