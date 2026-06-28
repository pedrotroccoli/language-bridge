class Translation < ApplicationRecord
  include Eventable

  belongs_to :project
  belongs_to :translation_key, counter_cache: true
  belongs_to :locale, counter_cache: true
  belongs_to :author, class_name: "User", optional: true

  has_one :publication, class_name: "Translation::Publication", dependent: :destroy
  has_one :review, class_name: "Translation::Review", dependent: :destroy
  has_one :approval, class_name: "Translation::Approval", dependent: :destroy
  has_many :versions, class_name: "Translation::Version", dependent: :delete_all

  validates :translation_key_id, uniqueness: { scope: :locale_id }
  validate :key_and_locale_share_project

  # project is denormalized for direct tenant scoping (compass bucket pattern);
  # it is derived from the key and never set by hand.
  before_validation :assign_project, on: :create

  scope :published, -> { joins(:publication) }
  scope :unpublished, -> { where.missing(:publication) }
  scope :approved, -> { joins(:approval) }
  scope :under_review, -> { joins(:review) }
  scope :untranslated, -> { where(value: nil) }
  scope :drafts, -> { where.not(value: [ nil, "" ]).where.missing(:publication) }
  scope :drafts_in_namespace, ->(namespace) {
    drafts.joins(:translation_key).where(translation_keys: { namespace_id: namespace.id })
  }

  before_update :snapshot_version, if: -> { value_changed? }
  after_update :discard_publication, if: -> { saved_change_to_value? }

  def draft?
    value.present? && publication.nil?
  end

  def published?
    publication.present?
  end

  # Publishing/unpublishing is a state-record transition: create or destroy the
  # Publication and record an event. Lives on the model so controllers stay thin.
  def publish(by: Current.user)
    return publication if published?

    transaction do
      create_publication!(publisher: by)
      track_event("published", creator: by)
    end
    Translation::Artifact.touch_for(self)
    publication
  end

  def unpublish
    return unless published?

    transaction do
      publication.destroy!
      association(:publication).reset
      track_event("unpublished")
    end
    Translation::Artifact.touch_for(self)
  end

  private
    def assign_project
      self.project ||= translation_key&.project
    end

    def key_and_locale_share_project
      return if translation_key.nil? || locale.nil?

      if translation_key.project_id != locale.project_id
        errors.add(:locale, "must belong to the same project as the key")
      end
    end

    def snapshot_version
      versions.create!(value: value_was, author_id: author_id_was)
    end

    # Editing the value invalidates any publication: the published content is
    # now stale, so the translation returns to draft (and the transition is
    # recorded, like an explicit unpublish).
    def discard_publication
      return if publication.nil?

      publication.destroy!
      association(:publication).reset
      track_event("unpublished", metadata: { reason: "value_changed" })

      Translation::Artifact.touch_for(self)
    end
end
