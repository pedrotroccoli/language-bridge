module Eventable
  extend ActiveSupport::Concern

  included do
    has_many :events, as: :eventable, dependent: :destroy
  end

  def track_event(action, creator: Current.user, metadata: {})
    events.create!(action:, creator:, metadata:)
  end
end
