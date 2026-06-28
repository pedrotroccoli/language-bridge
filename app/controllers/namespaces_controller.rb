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

    keys = @query.present? ? @namespace.translation_keys.search(@query) : @namespace.translation_keys.order(:key)

    @match_count = keys.count
    @page_limit = KEY_PAGE_LIMIT
    @translation_keys = keys.includes(translations: :publication).limit(KEY_PAGE_LIMIT)
    @draft_count = Translation.drafts_in_namespace(@namespace).count
    @new_translation_key = @namespace.translation_keys.build

    load_editor_stats
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
    def set_namespace
      @namespace = @project.namespaces.find_by!(name: params[:id])
    end

    def namespace_params
      params.expect(namespace: %i[ name ])
    end

    # Sidebar coverage + the translated/draft/missing tallies for this namespace.
    def load_editor_stats
      scoped = Translation.joins(:translation_key)
                          .where(translation_keys: { namespace_id: @namespace.id })

      filled = scoped.where.not(value: [ nil, "" ]).group(:locale_id).count
      @locale_coverage = @locales.each_with_object({}) do |locale, map|
        map[locale.id] = @total_keys.zero? ? 0 : ((filled[locale.id].to_i.to_f / @total_keys) * 100).round.clamp(0, 100)
      end

      slots = @total_keys * @locales.size
      filled_total = filled.values.sum
      @stats = {
        translated: scoped.published.count,
        drafts: @draft_count,
        missing: [ slots - filled_total, 0 ].max,
        total: slots,
        changed_7: scoped.where("translations.updated_at >= ?", 7.days.ago).count,
        changed_30: scoped.where("translations.updated_at >= ?", 30.days.ago).count
      }
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
