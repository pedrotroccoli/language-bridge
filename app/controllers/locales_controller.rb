class LocalesController < ApplicationController
  include ProjectScoped

  before_action :set_locale,                    only: %i[ update destroy ]
  before_action :ensure_can_administer_project, only: %i[ create update destroy ]

  # The DB unique index is the source of truth; a true race that slips past the
  # model validation surfaces here as a duplicate-code error.
  rescue_from ActiveRecord::RecordNotUnique, with: :code_already_taken

  def create
    @locale = @project.locales.build(locale_params)

    if @locale.save
      redirect_to project_path(@project), notice: "Locale created.", status: :see_other
    else
      redirect_with_invalid_locale
    end
  end

  def update
    if @locale.update(locale_params)
      redirect_to project_path(@project), notice: "Locale updated.", status: :see_other
    else
      redirect_with_locale_alert
    end
  end

  def destroy
    @locale.destroy!
    redirect_to project_path(@project), notice: "Locale deleted.", status: :see_other
  end

  private
    def set_locale
      @locale = @project.locales.find(params[:id])
    end

    def locale_params
      params.expect(locale: %i[ code ])
    end

    def code_already_taken
      @locale.errors.add(:code, "has already been taken")
      action_name == "create" ? redirect_with_invalid_locale : redirect_with_locale_alert
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
