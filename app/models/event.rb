class Event < ApplicationRecord
  belongs_to :eventable, polymorphic: true
  belongs_to :creator, class_name: "User", optional: true,
    default: -> { Current.user }

  validates :action, presence: true

  # Predicate access: event.action.published? instead of action == "published".
  def action
    self[:action]&.inquiry
  end
end
