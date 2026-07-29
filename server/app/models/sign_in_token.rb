class SignInToken < ApplicationRecord
  EXPIRES_IN = 15.minutes

  belongs_to :user

  has_secure_token :token, length: 36

  before_validation { self.expires_at ||= EXPIRES_IN.from_now }

  scope :fresh, -> { where("expires_at > ?", Time.current) }

  def expired?
    expires_at < Time.current
  end
end
