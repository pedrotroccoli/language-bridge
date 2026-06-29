# ActiveRecord Encryption keys for at-rest encryption of secrets (e.g. storage
# connection access keys). Production reads them from the environment so a
# misconfigured deploy fails loudly rather than silently encrypting with a weak,
# derived key. Development/test derive deterministic, domain-separated keys from
# secret_key_base so the app boots with zero setup (those environments never hold
# real cloud secrets).
Rails.application.configure do
  enc = config.active_record.encryption

  if Rails.env.local?
    generator = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base, hash_digest_class: OpenSSL::Digest::SHA256)
    enc.primary_key         = ENV["AR_ENCRYPTION_PRIMARY_KEY"]         || generator.generate_key("ar-encryption-primary", 32)
    enc.deterministic_key   = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]   || generator.generate_key("ar-encryption-deterministic", 32)
    enc.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"] || generator.generate_key("ar-encryption-salt", 32)
    # Tolerate the pre-encryption NULL/plaintext rows only outside production.
    enc.support_unencrypted_data = true
  else
    enc.primary_key         = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY")
    enc.deterministic_key   = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY")
    enc.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT")
  end
end
