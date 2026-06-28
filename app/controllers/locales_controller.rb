class LocalesController < ApplicationController
  before_action :set_project
  before_action :set_locale,                    only: %i[ update destroy ]
  before_action :ensure_can_administer_project, only: %i[ create update destroy ]

  def create
    @locale = @project.locales.build(locale_params)

    if @locale.save
      redirect_to project_path(@project), notice: "Locale created.", status: :see_other
    else
      redirect_with_invalid_locale
    end
  rescue ActiveRecord::RecordNotUnique
    @locale.errors.add(:code, "has already been taken")
    redirect_with_invalid_locale
  end

  def update
    if @locale.update(locale_params)
      redirect_to project_path(@project), notice: "Locale updated.", status: :see_other
    else
      redirect_with_locale_alert
    end
  rescue ActiveRecord::RecordNotUnique
    @locale.errors.add(:code, "has already been taken")
    redirect_with_locale_alert
  end

  def destroy
    @locale.destroy!
    redirect_to project_path(@project), notice: "Locale deleted.", status: :see_other
  end

  private
    def set_project
      @project = current_user.accessible_projects.find_by!(slug: params[:project_id])
    end

    def set_locale
      @locale = @project.locales.find(params[:id])
    end

    def locale_params
      params.expect(locale: %i[ code ])
    end

    def ensure_can_administer_project
      head :forbidden unless current_user&.can_administer_project?(@project)
    end

    def redirect_with_invalid_locale
      flash[:invalid_locale_code] = locale_params[:code]
      redirect_with_locale_alert
    end

    def redirect_with_locale_alert
      redirect_to project_path(@project),
                  alert: @locale.errors.full_messages.to_sentence,
                  status: :see_other
    end
end
