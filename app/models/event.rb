class Event < ApplicationRecord
  belongs_to :eventable, polymorphic: true
  belongs_to :creator, class_name: "User", optional: true,
    default: -> { Current.user }

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # All events belonging to a project: its own, plus its keys and translations.
  def self.for_project(project)
    where(eventable_type: "Translation", eventable_id: project.translations.select(:id))
      .or(where(eventable_type: "TranslationKey", eventable_id: project.translation_keys.select(:id)))
      .or(where(eventable_type: "Project", eventable_id: project.id))
      .includes(:creator, :eventable)
  end

  # Predicate access: event.action.published? instead of action == "published".
  def action
    self[:action]&.inquiry
  end
end
