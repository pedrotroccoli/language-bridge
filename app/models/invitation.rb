class Invitation < ApplicationRecord
  EXPIRES_IN = 7.days

  belongs_to :inviter, class_name: "User"

  has_secure_token :token, length: 36

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true
  validates :role, inclusion: { in: User::ROLES }
  validate :email_not_taken_by_user, on: :create

  before_validation { self.expires_at ||= EXPIRES_IN.from_now }

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }

  def accepted?
    accepted_at.present?
  end

  def expired?
    expires_at < Time.current
  end

  def claimable?
    !accepted? && !expired?
  end

  def accept!(now: Time.current)
    transaction do
      user = User.create!(email: email, role: role)
      update!(accepted_at: now)
      user
    end
  end

  private
    def email_not_taken_by_user
      errors.add(:email, "is already registered") if email.present? && User.exists?(email: email)
    end
end
