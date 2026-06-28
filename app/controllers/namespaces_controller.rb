class NamespacesController < ApplicationController
  KEY_PAGE_LIMIT = 100

  before_action :set_project
  before_action :set_namespace,                 only: %i[ show update destroy publish_all import ]
  before_action :ensure_can_administer_project, only: %i[ create update destroy import ]
  before_action :ensure_can_edit_translations,  only: %i[ publish_all ]

  def show
    @locales = @project.locales.alphabetically
    @query = params[:q].to_s.strip
    @total_keys = @namespace.translation_keys.count

    if @query.present?
      like = "%#{TranslationKey.sanitize_sql_like(@query)}%"
      quoted = TranslationKey.connection.quote(like)

      # Match on the key OR any of its translation values; rank key matches first.
      matched_ids = @namespace.translation_keys
                              .left_joins(:translations)
                              .where("translation_keys.key ILIKE :q OR translations.value ILIKE :q", q: like)
                              .select(:id).distinct
      scope = @namespace.translation_keys
                        .where(id: matched_ids)
                        .reorder(Arel.sql("CASE WHEN translation_keys.key ILIKE #{quoted} THEN 0 ELSE 1 END"), :key)
    else
      scope = @namespace.translation_keys.order(:key)
    end

    @match_count = scope.count
    @page_limit = KEY_PAGE_LIMIT
    @translation_keys = scope.includes(translations: :publication).limit(KEY_PAGE_LIMIT)
    @draft_count = namespace_draft_count(@namespace)
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

  def publish_all
    drafts = namespace_drafts(@namespace)
    count = drafts.count
    drafts.find_each { |translation| translation.create_publication! }

    notice = count.zero? ? "Nothing to publish." : "Published #{count} #{"translation".pluralize(count)}."
    redirect_to project_namespace_path(@project, @namespace), notice: notice, status: :see_other
  end

  def import
    locale = @project.locales.find_by(id: params[:locale_id])
    return redirect_to_namespace(alert: "Select a locale to import into.") if locale.nil?

    file = params[:file]
    return redirect_to_namespace(alert: "Choose a JSON file to import.") if file.blank?

    result = TranslationImport.new(namespace: @namespace, locale: locale, author: current_user).import(file.read)
    redirect_to_namespace(notice: "Imported #{result.translations_written} " \
      "#{"translation".pluralize(result.translations_written)} into #{locale.code} " \
      "(#{result.keys_created} new #{"key".pluralize(result.keys_created)}).")
  rescue TranslationImport::Error => e
    redirect_to_namespace(alert: "Import failed: #{e.message}")
  end

  private
    def redirect_to_namespace(**flash_opts)
      redirect_to project_namespace_path(@project, @namespace), status: :see_other, **flash_opts
    end

    def set_project
      @project = current_user.accessible_projects.find_by!(slug: params[:project_id])
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

    def ensure_can_edit_translations
      head :forbidden unless current_user&.can_edit_translations?(@project)
    end

    def namespace_drafts(namespace)
      Translation.drafts_in_namespace(namespace)
    end

    def namespace_draft_count(namespace)
      namespace_drafts(namespace).count
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
