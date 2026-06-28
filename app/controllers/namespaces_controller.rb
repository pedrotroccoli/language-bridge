class NamespacesController < ApplicationController
  include ProjectScoped

  KEY_PAGE_LIMIT = 100

  before_action :set_namespace,                 only: %i[ show update destroy ]
  before_action :ensure_can_administer_project, only: %i[ create update destroy ]

  def show
    @locales = @project.locales.alphabetically
    @query = params[:q].to_s.strip
    @total_keys = @namespace.translation_keys.count

    keys = @query.present? ? @namespace.translation_keys.search(@query) : @namespace.translation_keys.order(:key)

    @match_count = keys.count
    @page_limit = KEY_PAGE_LIMIT
    @translation_keys = keys.includes(translations: :publication).limit(KEY_PAGE_LIMIT)
    @draft_count = Translation.drafts_in_namespace(@namespace).count
    @new_translation_key = @namespace.translation_keys.build
  end

  def create
    @namespace = @project.namespaces.build(namespace_params)

    if @namespace.save
      redirect_to project_path(@project), notice: "Namespace created.", status: :see_other
    else
      redirect_with_invalid_namespace
    end
  rescue ActiveRecord::RecordNotUnique
    @namespace.errors.add(:name, "has already been taken")
    redirect_with_invalid_namespace
  end

  def update
    if @namespace.update(namespace_params)
      redirect_to project_path(@project), notice: "Namespace updated.", status: :see_other
    else
      redirect_with_namespace_alert
    end
  rescue ActiveRecord::RecordNotUnique
    @namespace.errors.add(:name, "has already been taken")
    redirect_with_namespace_alert
  end

  def destroy
    @namespace.destroy!
    redirect_to project_path(@project), notice: "Namespace deleted.", status: :see_other
  end

  private
    def set_namespace
      @namespace = @project.namespaces.find_by!(name: params[:id])
    end

    def namespace_params
      params.expect(namespace: %i[ name ])
    end

    def redirect_with_invalid_namespace
      flash[:invalid_namespace_name] = namespace_params[:name]
      redirect_with_namespace_alert
    end

    def redirect_with_namespace_alert
      redirect_to project_path(@project),
                  alert: @namespace.errors.full_messages.to_sentence,
                  status: :see_other
    end
end
