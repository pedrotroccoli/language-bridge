class User < ApplicationRecord
  ROLES = %w[ admin translator viewer ].freeze

  has_many :sessions, dependent: :destroy
  has_many :sign_in_tokens, dependent: :destroy
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :inviter_id, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }

  def admin?      = role == "admin"
  def translator? = role == "translator"
  def viewer?     = role == "viewer"
end
