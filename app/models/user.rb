class User < ApplicationRecord
  ROLES = %w[ admin translator viewer ].freeze

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
end
