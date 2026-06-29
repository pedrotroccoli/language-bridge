class NamespacesController < ApplicationController
  include ProjectScoped

  KEY_PAGE_LIMIT = 100

  before_action :set_namespace,                 only: %i[ show update destroy ]
  before_action :ensure_can_administer_project, only: %i[ create update destroy ]

  rescue_from ActiveRecord::RecordNotUnique, with: :name_already_taken

  def show
    @namespaces = @project.namespaces.alphabetically
    @locales = @project.locales.alphabetically
    @query = params[:q].to_s.strip

    # Locale-column visibility: ?locales[]=en&locales[]=pt-BR. Empty = show all.
    selected = Array(params[:locales]).map { |c| c.to_s.strip }.reject(&:blank?)
    @column_locales = selected.any? ? @locales.select { |l| selected.include?(l.code) } : @locales
    @column_locales = @locales if @column_locales.empty?

    @total_keys = @namespace.translation_keys.count

    # Status filter: All (default), Drafts (unpublished with a value), Review.
    @status = params[:status].to_s.presence_in(%w[ drafts review ])

    keys = @query.present? ? @namespace.translation_keys.search(@query) : @namespace.translation_keys.order(:key)
    keys = filter_by_status(keys, @status)

    @match_count = keys.count
    @page_limit = KEY_PAGE_LIMIT
    @translation_keys = keys.includes(translations: :publication).limit(KEY_PAGE_LIMIT)

    overview = @namespace.editor_overview(@locales, total_keys: @total_keys)
    @stats = overview[:stats]
    @locale_coverage = overview[:coverage]
    @draft_count = @stats[:drafts]
    @new_translation_key = @namespace.translation_keys.build
  end

  def create
    @namespace = @project.namespaces.build(namespace_params)

    if @namespace.save
      redirect_to project_path(@project), notice: "Namespace created.", status: :see_other
    else
      redirect_with_invalid_namespace
    end
  end

  def update
    if @namespace.update(namespace_params)
      redirect_to project_path(@project), notice: "Namespace updated.", status: :see_other
    else
      redirect_with_namespace_alert
    end
  end

  def destroy
    @namespace.destroy!
    redirect_to project_path(@project), notice: "Namespace deleted.", status: :see_other
  end

  private
    # Narrow a keys relation to those with a draft / under-review translation in
    # this namespace. nil status returns the relation unchanged (All).
    def filter_by_status(keys, status)
      case status
      when "drafts"
        keys.where(id: Translation.drafts_in_namespace(@namespace).select(:translation_key_id))
      when "review"
        review_key_ids = Translation.under_review.joins(:translation_key)
                                    .where(translation_keys: { namespace_id: @namespace.id })
                                    .select(:translation_key_id)
        keys.where(id: review_key_ids)
      else
        keys
      end
    end

    def set_namespace
      @namespace = @project.namespaces.find_by!(name: params[:id])
    end

    def namespace_params
      params.expect(namespace: %i[ name ])
    end

    def name_already_taken
      @namespace.errors.add(:name, "has already been taken")
      action_name == "create" ? redirect_with_invalid_namespace : redirect_with_namespace_alert
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
