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
