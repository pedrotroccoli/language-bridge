class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user_agent, :ip_address
  attribute :artifact_rebuild_batch

  def user
    session&.user
  end
end
