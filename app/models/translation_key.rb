class TranslationKey < ApplicationRecord
  include Eventable

  belongs_to :project, counter_cache: true
  belongs_to :namespace, counter_cache: true

  has_many :translations, dependent: :destroy

  validates :key, presence: true, uniqueness: { scope: [ :project_id, :namespace_id ] }

  scope :with_translations, ->(locale) { includes(:translations).where(translations: { locale: }) }
end
