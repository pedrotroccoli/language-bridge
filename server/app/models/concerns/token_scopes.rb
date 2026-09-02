# Shared capability set for bearer tokens (PersonalAccessToken, ApiToken). A
# token carries an independent set of capabilities rather than a single tier, so
# permissions compose freely (e.g. read + read_drafts without write). `admin`
# implies every capability.
module TokenScopes
  extend ActiveSupport::Concern

  # Ordered from least to most privilege (order used for stable display only —
  # the set is not hierarchical).
  CAPABILITIES = %w[ read read_drafts write admin ].freeze

  # Human labels for the UI.
  LABELS = {
    "read" => "Read published",
    "read_drafts" => "Read drafts",
    "write" => "Write drafts",
    "admin" => "Admin"
  }.freeze

  included do
    validate :scopes_are_known
  end

  # Does this token grant a capability? `admin` grants everything.
  def grants?(capability)
    scopes.include?("admin") || scopes.include?(capability.to_s)
  end

  private
    def scopes_are_known
      unknown = Array(scopes).map(&:to_s) - CAPABILITIES
      errors.add(:scopes, "contains unknown capabilities: #{unknown.join(', ')}") if unknown.any?
    end
end
