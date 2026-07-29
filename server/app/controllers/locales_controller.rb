class LocalesController < ApplicationController
  include ProjectScoped

  before_action :set_locale,                    only: %i[ update destroy source ]
  before_action :ensure_can_administer_project, only: %i[ create update destroy source ]

  # The DB unique index is the source of truth; a true race that slips past the
  # model validation surfaces here as a duplicate-code error.
  rescue_from ActiveRecord::RecordNotUnique, with: :code_already_taken

  def create
    codes = Array(params.dig(:locale, :codes)).filter_map { |c| c.to_s.strip.presence }.uniq

    if codes.any?
      create_many(codes)
    elsif params.dig(:locale, :code).present?
      create_one
    else
      redirect_to project_path(@project), alert: "Pick at least one language.", status: :see_other
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

  def source
    @locale.mark_as_source!
    redirect_to project_path(@project), notice: "#{@locale.code} is now the source locale.", status: :see_other
  end

  private
    def set_locale
      @locale = @project.locales.find(params[:id])
    end

    def locale_params
      params.expect(locale: %i[ code ])
    end

    def create_one
      @locale = @project.locales.build(locale_params)

      if @locale.save
        prefill_with_mt([ @locale ])
        redirect_to project_path(@project), notice: "Locale created.", status: :see_other
      else
        redirect_with_invalid_locale
      end
    end

    # Add several locales at once; duplicates/invalid codes are skipped.
    # Atomic: an unexpected failure rolls the whole batch back rather than
    # leaving a partial set behind.
    def create_many(codes)
      results = Project.transaction { codes.map { |code| @project.locales.create(code: code) } }
      prefill_with_mt(results.select(&:persisted?))
      created = results.count(&:persisted?)
      skipped = results.reject(&:persisted?).map(&:code)

      if created.zero?
        redirect_to project_path(@project),
                    alert: "Couldn't add #{skipped.to_sentence} (already present or invalid).",
                    status: :see_other
      elsif skipped.any?
        redirect_to project_path(@project),
                    notice: "Added #{created} #{"locale".pluralize(created)} · skipped #{skipped.to_sentence}.",
                    status: :see_other
      else
        redirect_to project_path(@project),
                    notice: "Added #{created} #{"locale".pluralize(created)}.",
                    status: :see_other
      end
    end

    # Optionally machine-translate empty keys for freshly added locales (drafts),
    # when the "pre-fill" box was checked and a source locale exists.
    def prefill_with_mt(locales)
      return unless params[:prefill_mt].present? && @project.source_locale

      locales.each { |locale| MachineTranslationJob.perform_later(locale) unless locale.is_source }
    end

    def code_already_taken
      # Bulk create never builds @locale; a race there just reports generically.
      return redirect_to(project_path(@project), alert: "That locale already exists.", status: :see_other) if @locale.nil?

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
