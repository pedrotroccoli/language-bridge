class Namespace < ApplicationRecord
  NAME_FORMAT = /\A[a-z0-9][a-z0-9_\-\.]*\z/

  belongs_to :project, counter_cache: true

  validates :name, presence: true,
                   format: { with: NAME_FORMAT, message: "must be lowercase alnum with -, _, . (no leading separator)" },
                   uniqueness: { scope: :project_id }

  scope :alphabetically, -> { order(name: :asc) }

  def to_param = name
end
