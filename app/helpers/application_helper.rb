module ApplicationHelper
  # Material Symbols (Outlined) icon. Size in px, weight 100..700, fill 0/1.
  def material_icon(name, size: 18, weight: 300, fill: 0, css: nil, title: nil)
    styles = "font-size:#{size}px;font-variation-settings:'wght' #{weight},'FILL' #{fill}"
    tag.span(name,
      class: [ "material-symbols-outlined", css ],
      style: styles,
      "aria-hidden": ("true" unless title),
      title: title)
  end
  alias_method :mi, :material_icon

  # Initials from a name or email, for avatar chips.
  def initials_for(value)
    source = value.to_s.strip
    return "?" if source.blank?

    if source.include?("@")
      source[0].upcase
    else
      source.split(/\s+/).first(2).map { |w| w[0] }.join.upcase
    end
  end

  # Ten-segment progress array (booleans) for the card meters.
  def progress_segments(percent, count: 10)
    on = ((percent.to_f / 100) * count).round
    Array.new(count) { |i| i < on }
  end

  # Active state for top-nav links, by controller name.
  def nav_active?(*controllers)
    controllers.flatten.map(&:to_s).include?(controller_name)
  end

  # Human name for a locale code (e.g. "pt-BR" => "Português (BR)"), or nil.
  def locale_name(code)
    Locale.name_for(code)
  end

  # Country-flag emoji for a locale code. Uses the region subtag when present
  # (en-GB → 🇬🇧, pt-BR → 🇧🇷), else the language's default country (fr → 🇫🇷).
  # Returns nil when no country can be inferred (e.g. es-419), so callers fall
  # back to a generic icon.
  LANG_DEFAULT_COUNTRY = {
    "en" => "US", "pt" => "PT", "es" => "ES", "fr" => "FR", "de" => "DE", "it" => "IT",
    "nl" => "NL", "ru" => "RU", "uk" => "UA", "pl" => "PL", "tr" => "TR", "ar" => "SA",
    "he" => "IL", "fa" => "IR", "hi" => "IN", "bn" => "BD", "ur" => "PK", "ja" => "JP",
    "ko" => "KR", "zh" => "CN", "th" => "TH", "vi" => "VN", "id" => "ID", "ms" => "MY",
    "fil" => "PH", "sv" => "SE", "da" => "DK", "nb" => "NO", "no" => "NO", "fi" => "FI",
    "is" => "IS", "cs" => "CZ", "sk" => "SK", "hu" => "HU", "ro" => "RO", "el" => "GR",
    "bg" => "BG", "hr" => "HR", "sr" => "RS", "sl" => "SI", "et" => "EE", "lv" => "LV",
    "lt" => "LT", "ca" => "ES", "eu" => "ES", "gl" => "ES", "af" => "ZA", "sw" => "KE",
    "ta" => "IN", "te" => "IN", "ml" => "IN", "kn" => "IN", "mr" => "IN", "gu" => "IN", "pa" => "IN"
  }.freeze

  def locale_flag(code)
    parts = code.to_s.split("-")
    region = parts[1..].to_a.find { |p| p.match?(/\A[A-Za-z]{2}\z/) }&.upcase
    region ||= LANG_DEFAULT_COUNTRY[parts.first.to_s.downcase]
    return unless region

    region.each_char.map { |c| (c.ord - "A".ord + 0x1F1E6).chr(Encoding::UTF_8) }.join
  end

  # A spinner span that the button-loading Stimulus controller toggles. Hidden
  # until the button's form starts submitting.
  def button_spinner
    tag.span(
      class: "hidden w-[14px] h-[14px] rounded-full border-2 border-current border-t-transparent animate-spin mr-[7px] flex-none",
      data: { "button-loading-target": "spinner" },
      "aria-hidden": "true"
    )
  end

  # button_to with a built-in loading spinner (shown while its form submits).
  # Same signature as button_to; pass icon: to prepend a material icon.
  def loading_button_to(label, url, icon: nil, **opts)
    opts[:class] ||= "btn"
    opts[:data] = (opts[:data] || {}).merge(controller: "button-loading")
    button_to(url, **opts) do
      safe_join([ button_spinner, (icon ? mi(icon, size: 16, css: "mr-[5px]") : nil), label ].compact)
    end
  end

  # A form submit button (form.button) with a built-in loading spinner.
  def loading_submit(form, label, icon: nil, **opts)
    opts[:class] ||= "btn"
    opts[:data] = (opts[:data] || {}).merge(controller: "button-loading")
    form.button(type: :submit, **opts) do
      safe_join([ button_spinner, (icon ? mi(icon, size: 16, css: "mr-[5px]") : nil), label ].compact)
    end
  end

  # [label, bytes] pairs for the upload max-size select.
  def upload_size_options
    [ 1, 2, 5, 10, 25, 50 ].map { |mb| [ "#{mb} MB", mb.megabytes ] }
  end

  # 24 hourly options for the backup run-at select, as [label, hour].
  def backup_hour_options
    (0..23).map { |h| [ format("%02d:00", h), h ] }
  end

  # Per-service field metadata for the storage-connection form. The view renders
  # these as data-* on each service radio; connection_form_controller reads the
  # checked radio to show the right fields/labels — no service config in JS.
  STORAGE_SERVICE_FIELDS = {
    "local" => { label: "Local", cloud: false },
    "s3"    => { label: "S3",    cloud: true, region: true,  endpoint: true,  bucket_label: "Bucket",    bucket_placeholder: "my-bucket-prod", key_label: "Access key ID", secret_label: "Secret access key" },
    "gcs"   => { label: "GCS",   cloud: true, region: false, endpoint: false, bucket_label: "Bucket",    bucket_placeholder: "my-bucket",      key_label: "Project ID",    secret_label: "Service account JSON" },
    "azure" => { label: "Azure", cloud: true, region: false, endpoint: false, bucket_label: "Container", bucket_placeholder: "my-container",   key_label: "Account name",  secret_label: "Access key" }
  }.freeze

  def storage_service_fields
    STORAGE_SERVICE_FIELDS
  end

  # Common AWS regions for the storage-connection region select.
  def aws_region_options
    [
      [ "US East (N. Virginia) · us-east-1", "us-east-1" ],
      [ "US East (Ohio) · us-east-2", "us-east-2" ],
      [ "US West (N. California) · us-west-1", "us-west-1" ],
      [ "US West (Oregon) · us-west-2", "us-west-2" ],
      [ "Canada (Central) · ca-central-1", "ca-central-1" ],
      [ "South America (São Paulo) · sa-east-1", "sa-east-1" ],
      [ "EU (Ireland) · eu-west-1", "eu-west-1" ],
      [ "EU (London) · eu-west-2", "eu-west-2" ],
      [ "EU (Paris) · eu-west-3", "eu-west-3" ],
      [ "EU (Frankfurt) · eu-central-1", "eu-central-1" ],
      [ "Asia Pacific (Mumbai) · ap-south-1", "ap-south-1" ],
      [ "Asia Pacific (Singapore) · ap-southeast-1", "ap-southeast-1" ],
      [ "Asia Pacific (Sydney) · ap-southeast-2", "ap-southeast-2" ],
      [ "Asia Pacific (Tokyo) · ap-northeast-1", "ap-northeast-1" ]
    ]
  end

  # Humanized description of an activity Event: { verb:, target:, meta: }.
  def event_summary(event)
    action = event.action.to_s
    case event.eventable_type
    when "Translation"
      t = event.eventable
      { verb: action.humanize.downcase, target: t&.translation_key&.key, meta: t&.locale&.code }
    when "TranslationKey"
      { verb: action.humanize.downcase, target: event.eventable&.key, meta: nil }
    when "Project"
      md = event.metadata || {}
      if action == "translations_imported"
        { verb: "imported #{md["translations_written"]} translations into", target: md["namespace"], meta: md["locale"] }
      else
        { verb: action.humanize.downcase, target: event.eventable&.name, meta: nil }
      end
    else
      { verb: action.humanize.downcase, target: nil, meta: nil }
    end
  end
end
