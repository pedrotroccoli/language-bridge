# Machine-translation facade with a pluggable provider. The default is a stub
# that produces an obviously-machine draft (no external API) — swap in a real
# provider (DeepL/Google/LLM) by registering it in PROVIDERS and setting the
# MT_PROVIDER env var. Results are always drafts; nothing here publishes.
class MachineTranslation
  # Deterministic offline stand-in. Tags the text with the target locale so it's
  # clearly unreviewed, while still round-tripping the source content.
  class StubProvider
    def translate(text, from:, to:)
      return text if text.blank?

      "[#{to}] #{text}"
    end
  end

  PROVIDERS = { "stub" => StubProvider }.freeze

  def self.provider
    PROVIDERS.fetch(ENV.fetch("MT_PROVIDER", "stub")).new
  end

  def self.translate(text, from:, to:)
    provider.translate(text, from: from, to: to)
  end
end
