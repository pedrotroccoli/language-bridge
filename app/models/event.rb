class Event < ApplicationRecord
  belongs_to :eventable, polymorphic: true
  belongs_to :creator, class_name: "User", optional: true,
    default: -> { Current.user }

  validates :action, presence: true
end
