class Locale < ApplicationRecord
  belongs_to :project, counter_cache: true

  has_many :translations, dependent: :destroy

  validates :code, presence: true, uniqueness: { scope: :project_id }

  scope :alphabetically, -> { order(code: :asc) }
end
