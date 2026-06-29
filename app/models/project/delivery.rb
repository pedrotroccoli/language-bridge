# Public delivery: the deterministic object keys published (namespace, locale)
# artifacts are materialized at, and re-materialization across the project.
module Project::Delivery
  extend ActiveSupport::Concern

  # Tokens allowed in delivery_path_template (see #delivery_key_for).
  TOKENS = %w[ project_slug namespace locale ].freeze

  included do
    validates :delivery_path_template, presence: true
    validate :delivery_path_template_well_formed
  end

  # Deterministic key for a materialized (namespace, locale) artifact, rendered
  # from delivery_path_template. Lets a self-hoster point a CDN origin at a stable,
  # readable path in their bucket. See issue #77 / docs/delivery-paths.md.
  def delivery_key_for(namespace, locale)
    delivery_path_template
      .gsub("{project_slug}", slug)
      .gsub("{namespace}", namespace.name)
      .gsub("{locale}", locale.code)
  end

  # The full storage key (connection prefix + upload_path + delivery key) the
  # artifact blob is written at, so published files sit beside the backups.
  def delivery_storage_key(namespace, locale)
    storage_key(delivery_key_for(namespace, locale))
  end

  # Re-materialize every published (namespace, locale) at the current template
  # (purging blobs at any previous keys). Returns the count. Synchronous for now —
  # heavy instances should move this to a job (issue #43).
  def rematerialize_delivery!
    pairs = translations.published.joins(:translation_key)
              .distinct.pluck("translation_keys.namespace_id", :locale_id)
    pairs.each { |namespace_id, locale_id| Translation::Artifact.rebuild(namespace_id, locale_id) }
    pairs.size
  end

  private
    # Template must render a relative key (no leading "/"), use only known tokens,
    # include {namespace} and {locale} (so each pair is unique), and contain only
    # path-safe literal characters.
    def delivery_path_template_well_formed
      template = delivery_path_template.to_s
      return if template.blank?

      errors.add(:delivery_path_template, "must not start with /") if template.start_with?("/")

      template.scan(/\{(\w+)\}/).flatten.uniq.each do |token|
        errors.add(:delivery_path_template, "has unknown token {#{token}}") unless TOKENS.include?(token)
      end

      errors.add(:delivery_path_template, "must include {namespace}") unless template.include?("{namespace}")
      errors.add(:delivery_path_template, "must include {locale}")    unless template.include?("{locale}")

      literal = template.gsub(/\{\w+\}/, "")
      errors.add(:delivery_path_template, "has invalid characters") unless literal.match?(%r{\A[A-Za-z0-9/_\-.]*\z})
    end
end
