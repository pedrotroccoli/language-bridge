class ProjectsController < ApplicationController
  before_action :set_project,                    only: %i[ show edit update destroy activity settings ]
  before_action :ensure_can_administer_project,  only: %i[ new create edit update destroy settings ]

  def index
    @projects = current_user.accessible_projects.alphabetically
    @coverage = coverage_for(@projects)
    fresh_when etag: [ @projects, @coverage, current_user ]
  end

  def show
    @namespaces = @project.namespaces.alphabetically
    @new_namespace = @project.namespaces.build(name: flash[:invalid_namespace_name])
    @locales = @project.locales.alphabetically
    @new_locale = @project.locales.build(code: flash[:invalid_locale_code])
    @locale_coverage = locale_coverage_for(@project)
  end

  def new
    @project = Project.new
  end

  def edit
  end

  def activity
    translations    = Event.where(eventable_type: "Translation", eventable_id: @project.translations.select(:id))
    translation_keys = Event.where(eventable_type: "TranslationKey", eventable_id: @project.translation_keys.select(:id))
    project_events  = Event.where(eventable_type: "Project", eventable_id: @project.id)

    @events = translations.or(translation_keys).or(project_events)
                          .includes(:creator, :eventable)
                          .order(created_at: :desc)
                          .limit(50)
  end

  def settings
    @locales = @project.locales.alphabetically
    @namespaces = @project.namespaces.alphabetically
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

    # Map of project id => translated coverage percent (non-blank translations
    # over the keys × locales grid). One grouped query for the whole index.
    def coverage_for(projects)
      filled = Translation.where(project_id: projects.map(&:id))
                          .where.not(value: [ nil, "" ])
                          .group(:project_id).count

      projects.each_with_object({}) do |project, map|
        slots = project.translation_keys_count * project.locales_count
        map[project.id] = slots.zero? ? 0 : ((filled[project.id].to_i.to_f / slots) * 100).round.clamp(0, 100)
      end
    end

    # Map of locale id => translated coverage percent (non-blank translations
    # over the project's total keys).
    def locale_coverage_for(project)
      keys = project.translation_keys_count
      filled = project.translations.where.not(value: [ nil, "" ]).group(:locale_id).count

      project.locales.each_with_object({}) do |locale, map|
        map[locale.id] = keys.zero? ? 0 : ((filled[locale.id].to_i.to_f / keys) * 100).round.clamp(0, 100)
      end
    end
end
