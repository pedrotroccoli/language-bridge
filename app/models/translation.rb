class Translation < ApplicationRecord
  include Eventable

  belongs_to :translation_key, counter_cache: true
  belongs_to :locale, counter_cache: true
  belongs_to :author, class_name: "User", optional: true

  has_one :publication, class_name: "Translation::Publication", dependent: :destroy
  has_one :review, class_name: "Translation::Review", dependent: :destroy
  has_one :approval, class_name: "Translation::Approval", dependent: :destroy
  has_many :versions, class_name: "Translation::Version", dependent: :destroy

  validates :translation_key_id, uniqueness: { scope: :locale_id }

  scope :published, -> { joins(:publication) }
  scope :unpublished, -> { where.missing(:publication) }
  scope :approved, -> { joins(:approval) }
  scope :under_review, -> { joins(:review) }
  scope :missing, -> { where(value: nil) }
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

  private
    def snapshot_version
      versions.create!(value: value_was, author_id: author_id_was)
    end

    # Editing the value invalidates any publication: the published content is
    # now stale, so the translation returns to draft.
    def discard_publication
      return if publication.nil?

      publication.destroy!
      association(:publication).reset
    end
end
