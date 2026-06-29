class TranslationKeysController < ApplicationController
  include ProjectScoped

  before_action :set_namespace
  before_action :set_translation_key,           only: %i[ update destroy ]
  before_action :ensure_can_administer_project, only: %i[ create update destroy ]

  rescue_from ActiveRecord::RecordNotUnique, with: :key_already_taken

  def create
    namespace = chosen_namespace
    @translation_key = namespace.translation_keys.build(translation_key_params.merge(project: @project))

    # Key and its source-locale draft are written together so a failed value
    # write never leaves a half-created key behind.
    ActiveRecord::Base.transaction do
      @translation_key.save!
      create_source_value(namespace)
    end
    redirect_to project_namespace_path(@project, namespace), notice: "Key created.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_with_alert(@translation_key)
  end

  def update
    if @translation_key.update(translation_key_params)
      redirect_to namespace_path, notice: "Key updated.", status: :see_other
    else
      redirect_with_alert(@translation_key)
    end
  end

  def destroy
    # The namespace survives, so any artifact that included this key must be
    # rebuilt without it. Capture the affected locales before the cascade.
    affected_locale_ids = @translation_key.translations.published.distinct.pluck(:locale_id)
    @translation_key.destroy!
    affected_locale_ids.each { |locale_id| Translation::Artifact.rebuild(@namespace.id, locale_id) }

    redirect_to namespace_path, notice: "Key deleted.", status: :see_other
  end

  private
    def set_namespace
      @namespace = @project.namespaces.find_by!(name: params[:namespace_id])
    end

    def set_translation_key
      @translation_key = @namespace.translation_keys.find(params[:id])
    end

    def translation_key_params
      params.expect(translation_key: %i[ key context ])
    end

    # The namespace to create into — the modal's select, falling back to the
    # current (route) namespace.
    def chosen_namespace
      id = params.dig(:translation_key, :namespace_id)
      id.present? ? @project.namespaces.find(id) : @namespace
    end

    # Seed the source-locale value (first locale) as a draft, if one was entered.
    def create_source_value(namespace)
      value = params.dig(:translation_key, :source_value).to_s
      return if value.blank?

      source = @project.locales.alphabetically.first or return
      @translation_key.set_translation(locale: source, value: value, author: current_user)
    end

    def key_already_taken
      @translation_key.errors.add(:key, "has already been taken")
      redirect_with_alert(@translation_key)
    end

    def namespace_path
      project_namespace_path(@project, @namespace)
    end

    def redirect_with_alert(record)
      flash[:invalid_translation_key] = translation_key_params[:key]
      redirect_to namespace_path, alert: record.errors.full_messages.to_sentence, status: :see_other
    end
end
