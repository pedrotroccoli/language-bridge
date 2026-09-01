# A staged translation the platform has NOT applied yet: an AI (or any
# save_missing token) pushes proposed values here instead of writing straight to
# Translation, so a live published string is never clobbered by an automated
# push. A human reviews the diff and accepts (materialise as draft) or rejects.
#
# The key is stored as a dotted string, not a TranslationKey row: a brand-new
# key never pollutes the project until a human accepts it. One open proposal per
# (namespace, key, locale) — a re-push overwrites the pending one. The author is
# the proposer (origin); acceptance records the accepting human separately.
class Translation::Proposal < ApplicationRecord
  belongs_to :project
  belongs_to :namespace
  belongs_to :locale
  belongs_to :author, class_name: "User", default: -> { Current.user }

  validates :key, presence: true
  validates :value, presence: true
  validates :key, uniqueness: { scope: [ :namespace_id, :locale_id, :session ] }
  validate :namespace_and_locale_share_project

  # project is denormalized for tenant scoping (mirrors Translation); derived
  # from the namespace, never set by hand.
  before_validation :assign_project, on: :create

  scope :recent, -> { order(created_at: :desc) }

  # Upsert a proposal for one (namespace, key, locale) within a session,
  # overwriting the pending value on re-push. Returns the persisted proposal.
  def self.propose(namespace:, key:, locale:, value:, author: Current.user, session: "")
    proposal = find_or_initialize_by(namespace: namespace, key: key, locale: locale, session: session.to_s)
    proposal.update!(value: value, author: author)
    proposal
  end

  # The existing key row this proposal targets, if any — nil for a brand-new key.
  def translation_key
    @translation_key ||= namespace.translation_keys.find_by(key: key)
  end

  # The translation this proposal would change, if one exists yet. Drives the
  # before/after diff shown for review.
  def current_value
    translation_key&.translations&.find_by(locale_id: locale_id)&.value
  end

  def new_key?
    translation_key.nil?
  end

  # Accept: create the key if needed, write the proposed value as a DRAFT (never
  # auto-publishing), keeping the proposer as the text's author, then clear the
  # proposal. Publishing stays a separate, human-authorised step. `by` is
  # recorded as the accepting user.
  def accept(by: Current.user)
    translation = nil
    transaction do
      key_record = namespace.translation_keys.find_or_create_by!(key: key) { |record| record.project = project }
      translation = key_record.set_translation(locale: locale, value: value, author: author)
      translation.track_event("proposal_accepted", creator: by, metadata: { proposer_id: author_id })
      destroy!
    end
    translation
  end

  # Reject: discard the proposal, recording who dismissed it.
  def reject(by: Current.user)
    transaction do
      project.track_event("proposal_rejected", creator: by, metadata: { namespace: namespace.name, key: key, locale: locale.code, proposer_id: author_id })
      destroy!
    end
  end

  private
    def assign_project
      self.project ||= namespace&.project
    end

    def namespace_and_locale_share_project
      return if namespace.nil? || locale.nil?

      if namespace.project_id != locale.project_id
        errors.add(:locale, "must belong to the same project as the namespace")
      end
    end
end
