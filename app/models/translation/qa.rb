# Lightweight quality checks for a translation, compared against its source.
# Pure functions (no DB) so callers pass the already-loaded source translation.
#
#   warnings — interpolation-placeholder mismatch vs source, or a length that's
#              wildly off (likely a copy/paste or truncation error).
#   fuzzy?   — the source was edited more recently than this translation, so the
#              translated text may be stale.
module Translation::Qa
  # Matches {{count}}, {name}, and %{name}-style interpolation tokens.
  PLACEHOLDER = /\{\{[^}]+\}\}|\{[^}]+\}|%\{[^}]+\}/

  LENGTH_MAX_RATIO = 3.0
  LENGTH_MIN_RATIO = 0.33
  LENGTH_FLOOR = 12 # don't flag length on very short strings

  module_function

  def placeholders(value)
    value.to_s.scan(PLACEHOLDER).map { |p| p.gsub(/\s+/, "") }.sort
  end

  # Array of human-readable warning strings (empty when clean).
  def warnings(translation, source)
    return [] if translation.nil? || translation.value.blank?

    list = []
    if source && source.value.present?
      list << "Placeholders differ from the source" if placeholders(translation.value) != placeholders(source.value)
      list << "Length looks off vs the source" if length_anomaly?(translation.value, source.value)
    end
    list
  end

  def fuzzy?(translation, source)
    return false if translation.nil? || source.nil? || translation == source
    return false if translation.value.blank? || source.value.blank?

    source.updated_at > translation.updated_at
  end

  def length_anomaly?(value, source_value)
    return false if source_value.length < LENGTH_FLOOR

    ratio = value.length.to_f / source_value.length
    ratio > LENGTH_MAX_RATIO || ratio < LENGTH_MIN_RATIO
  end
end
