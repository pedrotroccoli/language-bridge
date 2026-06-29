class Project < ApplicationRecord
  include Eventable
  include Storage, Backups, Delivery, Uploads

  BACKUP_FREQUENCIES = %w[ daily weekly monthly ].freeze
  BACKUP_FORMATS = Snapshot::FORMATS

  before_validation :generate_slug, on: :create

  has_many :namespaces, dependent: :destroy
  has_many :locales, dependent: :destroy
  has_many :translation_keys, dependent: :destroy
  has_many :translations, dependent: :destroy
  has_many :translation_artifacts, class_name: "Translation::Artifact", dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :missing_key_reports, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :backup_frequency, inclusion: { in: BACKUP_FREQUENCIES }
  validates :backup_format, inclusion: { in: BACKUP_FORMATS }
  validates :backup_retention, numericality: { only_integer: true, greater_than: 0 }
  validates :backup_time_of_day, numericality: { only_integer: true, in: 0..23 }

  scope :alphabetically, -> { order(name: :asc) }

  def to_param = slug

  # Per-IP rate limits, falling back to the global Setting when no override set.
  def effective_missing_limit  = missing_rate_limit  || Setting.current.missing_rate_limit
  def effective_delivery_limit = delivery_rate_limit || Setting.current.delivery_rate_limit

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
