class Project < ApplicationRecord
  include Eventable

  # Tokens allowed in delivery_path_template (see #delivery_key_for).
  DELIVERY_TOKENS = %w[ project_slug namespace locale ].freeze

  BACKUP_FREQUENCIES = %w[ daily weekly monthly ].freeze

  before_validation :generate_slug, on: :create

  has_many :namespaces, dependent: :restrict_with_exception
  has_many :locales, dependent: :destroy
  has_many :translation_keys, dependent: :destroy
  has_many :translations, dependent: :destroy
  has_many :translation_artifacts, class_name: "Translation::Artifact", dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :backups, class_name: "Project::Backup", dependent: :destroy
  has_many :missing_key_reports, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :delivery_path_template, presence: true
  validate :delivery_path_template_well_formed
  validates :backup_frequency, inclusion: { in: BACKUP_FREQUENCIES }
  validates :backup_retention, numericality: { only_integer: true, greater_than: 0 }

  scope :alphabetically, -> { order(name: :asc) }

  def to_param = slug

  # Per-IP rate limits, falling back to the global Setting when no override set.
  def effective_missing_limit  = missing_rate_limit  || Setting.current.missing_rate_limit
  def effective_delivery_limit = delivery_rate_limit || Setting.current.delivery_rate_limit

  # Deterministic Active Storage object key for a materialized (namespace, locale)
  # artifact, rendered from delivery_path_template. Lets a self-hoster point a CDN
  # origin at a stable, readable path in their own bucket. See issue #77 / docs/delivery-paths.md.
  def delivery_key_for(namespace, locale)
    delivery_path_template
      .gsub("{project_slug}", slug)
      .gsub("{namespace}", namespace.name)
      .gsub("{locale}", locale.code)
  end

  # How long between automatic snapshots, per backup_frequency.
  def backup_interval
    { "daily" => 1.day, "weekly" => 1.week, "monthly" => 1.month }.fetch(backup_frequency, 1.day)
  end

  # Is an automatic backup due? (enabled, and none taken within the interval)
  def backup_due?
    return false unless backups_enabled

    last = backups.maximum(:created_at)
    last.nil? || last <= backup_interval.ago
  end

  # Snapshot this project's translations to the configured storage and prune old
  # backups. Returns the Project::Backup (or nil if an auto backup was skipped
  # because nothing changed). Invoked by BackupProjectJob — kept here so the job
  # stays shallow and the behavior lives with the domain.
  def create_backup!(source: "manual")
    json = JSON.pretty_generate(TranslationSnapshot.build(self, include_drafts: backup_include_drafts))
    checksum = Digest::SHA256.hexdigest(json)
    return if source == "auto" && backups.recent.first&.checksum == checksum

    backup = backups.create!(source: source, checksum: checksum, translations_count: translations.count, byte_size: json.bytesize)
    backup.file.attach(**backup_attach_options(backup, json))
    backups.recent.offset(backup_retention).destroy_all # retention
    backup
  end

  # Re-materialize every published (namespace, locale) for this project at the
  # current template (purging blobs at any previous keys). Returns the count.
  # Synchronous for now — heavy instances should move this to a job (issue #43).
  def rematerialize_delivery!
    pairs = translations.published.joins(:translation_key)
              .distinct.pluck("translation_keys.namespace_id", :locale_id)
    pairs.each { |namespace_id, locale_id| Translation::Artifact.rebuild(namespace_id, locale_id) }
    pairs.size
  end

  # locale_id => percent of keys translated (non-blank value) for this project.
  def locale_coverage
    keys = translation_keys_count
    filled = translations.where.not(value: [ nil, "" ]).group(:locale_id).count

    locales.each_with_object({}) do |locale, map|
      map[locale.id] = keys.zero? ? 0 : ((filled[locale.id].to_i.to_f / keys) * 100).round.clamp(0, 100)
    end
  end

  # Activity feed: events on the project and its keys/translations, newest first.
  # Polymorphic `includes(:eventable)` can't reach a Translation's key/locale,
  # which event_summary needs — so preload those on the Translation subset to
  # keep the feed at a fixed query count instead of N+1.
  def recent_events(limit: 50)
    events = Event.for_project(self).recent.limit(limit).to_a
    translations = events.filter_map { |e| e.eventable if e.eventable_type == "Translation" }
    if translations.any?
      ActiveRecord::Associations::Preloader.new(
        records: translations, associations: [ :translation_key, :locale ]
      ).call
    end
    events
  end

  # Batched coverage for an index listing: id => translated percent.
  # One grouped query for the whole set, avoiding an N+1 across projects.
  def self.coverage_map(projects)
    filled = Translation.where(project_id: projects.map(&:id))
                        .where.not(value: [ nil, "" ])
                        .group(:project_id).count

    projects.each_with_object({}) do |project, map|
      slots = project.translation_keys_count * project.locales_count
      map[project.id] = slots.zero? ? 0 : ((filled[project.id].to_i.to_f / slots) * 100).round.clamp(0, 100)
    end
  end

  private
    def backup_attach_options(backup, json)
      options = {
        io: StringIO.new(json),
        key: "backups/#{slug}/#{backup.created_at.utc.strftime('%Y%m%d-%H%M%S')}-#{backup.id}.json",
        filename: "#{slug}.json",
        content_type: "application/json"
      }
      # Route to the workspace's default storage connection when one is set (and
      # its service is still registered).
      if (service_name = StorageConnection.default_service_name)
        options[:service_name] = service_name
      end
      options
    end

    # Template must: render a relative key (no leading "/"), use only known
    # tokens, include {namespace} and {locale} (so each pair gets a unique key),
    # and contain only path-safe literal characters.
    def delivery_path_template_well_formed
      template = delivery_path_template.to_s
      return if template.blank?

      errors.add(:delivery_path_template, "must not start with /") if template.start_with?("/")

      template.scan(/\{(\w+)\}/).flatten.uniq.each do |token|
        errors.add(:delivery_path_template, "has unknown token {#{token}}") unless DELIVERY_TOKENS.include?(token)
      end

      errors.add(:delivery_path_template, "must include {namespace}") unless template.include?("{namespace}")
      errors.add(:delivery_path_template, "must include {locale}")    unless template.include?("{locale}")

      literal = template.gsub(/\{\w+\}/, "")
      errors.add(:delivery_path_template, "has invalid characters") unless literal.match?(%r{\A[A-Za-z0-9/_\-.]*\z})
    end

    def generate_slug
      return if slug.present? || name.blank?

      base = name.parameterize
      candidate = base
      suffix = 2
      while Project.exists?(slug: candidate)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end
      self.slug = candidate
    end
end
