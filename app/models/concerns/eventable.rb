module Eventable
  extend ActiveSupport::Concern

  included do
    has_many :events, as: :eventable, dependent: :destroy
  end

  def track_event(action, metadata: {})
    events.create!(action:, metadata:)
  end
end
