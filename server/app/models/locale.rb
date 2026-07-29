class Locale < ApplicationRecord
  belongs_to :project, counter_cache: true

  has_many :translations, dependent: :destroy
  has_many :translation_artifacts, class_name: "Translation::Artifact", dependent: :destroy

  # IETF-ish language tag: 2–3 letter primary subtag, optional 2–8 alnum subtags.
  # Mirrors the combobox client pattern so server and UI agree.
  CODE_FORMAT = /\A[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*\z/

  validates :code, presence: true,
                   format: { with: CODE_FORMAT, message: "must be a valid locale tag (e.g. en, pt-BR)" },
                   uniqueness: { scope: :project_id }

  scope :alphabetically, -> { order(code: :asc) }
  scope :source, -> { where(is_source: true) }

  # Make this the project's single source locale, clearing any previous one.
  # The partial unique index guards the invariant; this keeps it consistent.
  def mark_as_source!
    transaction do
      project.locales.where.not(id: id).where(is_source: true).update_all(is_source: false)
      update!(is_source: true)
    end
  end

  # Common IETF language tags → human (mostly native) names. Powers the
  # locale picker and the "what language is this" label across the UI.
  CATALOG = [
    [ "en", "English" ], [ "en-US", "English (US)" ], [ "en-GB", "English (UK)" ],
    [ "pt", "Português" ], [ "pt-BR", "Português (BR)" ], [ "pt-PT", "Português (PT)" ],
    [ "es", "Español" ], [ "es-419", "Español (LatAm)" ], [ "es-ES", "Español (ES)" ],
    [ "fr", "Français" ], [ "fr-CA", "Français (CA)" ],
    [ "de", "Deutsch" ], [ "de-AT", "Deutsch (AT)" ],
    [ "it", "Italiano" ], [ "nl", "Nederlands" ],
    [ "ru", "Русский" ], [ "uk", "Українська" ], [ "pl", "Polski" ], [ "tr", "Türkçe" ],
    [ "ar", "العربية" ], [ "he", "עברית" ], [ "fa", "فارسی" ],
    [ "hi", "हिन्दी" ], [ "bn", "বাংলা" ], [ "ur", "اردو" ],
    [ "ja", "日本語" ], [ "ko", "한국어" ],
    [ "zh", "中文" ], [ "zh-CN", "简体中文" ], [ "zh-TW", "繁體中文" ], [ "zh-HK", "繁體中文 (HK)" ],
    [ "th", "ไทย" ], [ "vi", "Tiếng Việt" ], [ "id", "Bahasa Indonesia" ], [ "ms", "Bahasa Melayu" ], [ "fil", "Filipino" ],
    [ "sv", "Svenska" ], [ "da", "Dansk" ], [ "nb", "Norsk (Bokmål)" ], [ "no", "Norsk" ], [ "fi", "Suomi" ], [ "is", "Íslenska" ],
    [ "cs", "Čeština" ], [ "sk", "Slovenčina" ], [ "hu", "Magyar" ], [ "ro", "Română" ],
    [ "el", "Ελληνικά" ], [ "bg", "Български" ], [ "hr", "Hrvatski" ], [ "sr", "Српски" ], [ "sl", "Slovenščina" ],
    [ "et", "Eesti" ], [ "lv", "Latviešu" ], [ "lt", "Lietuvių" ],
    [ "ca", "Català" ], [ "eu", "Euskara" ], [ "gl", "Galego" ], [ "af", "Afrikaans" ], [ "sw", "Kiswahili" ],
    [ "ta", "தமிழ்" ], [ "te", "తెలుగు" ], [ "ml", "മലയാളം" ], [ "kn", "ಕನ್ನಡ" ], [ "mr", "मराठी" ], [ "gu", "ગુજરાતી" ], [ "pa", "ਪੰਜਾਬੀ" ]
  ].freeze

  CATALOG_BY_CODE = CATALOG.to_h { |code, name| [ code.downcase, name ] }.freeze

  # Human name for a code (case-insensitive), or nil if unknown.
  def self.name_for(code)
    CATALOG_BY_CODE[code.to_s.downcase]
  end

  def display_name
    self.class.name_for(code)
  end
end
