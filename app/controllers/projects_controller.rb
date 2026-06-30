class ProjectsController < ApplicationController
  before_action :set_project,                    only: %i[ show edit update destroy ]
  before_action :ensure_can_administer_project,  only: %i[ new create edit update destroy ]

  def index
    @projects = current_user.accessible_projects.alphabetically
    @coverage = Project.coverage_map(@projects)
    fresh_when etag: [ @projects, @coverage, current_user ]
  end

  def show
    @namespaces = @project.namespaces.alphabetically
    @new_namespace = @project.namespaces.build(name: flash[:invalid_namespace_name])
    @locales = @project.locales.alphabetically
    @new_locale = @project.locales.build(code: flash[:invalid_locale_code])
    @locale_coverage = @project.locale_coverage
  end

  def new
    @project = Project.new
  end

  def edit
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      create_source_locale
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @project.update(project_params)
      # A new path template re-keys every artifact (purging old blobs).
      @project.rematerialize_delivery! if @project.saved_change_to_delivery_path_template?
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
      params.expect(project: %i[ name missing_rate_limit delivery_rate_limit delivery_path_template ])
    end

    # The create form picks a source language; seed it as the project's first
    # locale, flagged as source. Invalid/blank codes are simply skipped.
    def create_source_locale
      code = params.dig(:project, :source_locale_code).to_s.strip
      return if code.blank?

      @project.locales.create(code: code, is_source: true)
    end

    def ensure_can_administer_project
      head :forbidden unless current_user&.can_administer_project?(@project)
    end
end
