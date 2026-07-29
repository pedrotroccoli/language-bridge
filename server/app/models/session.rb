class Session < ApplicationRecord
  belongs_to :user

  has_secure_token :token, length: 36
end
