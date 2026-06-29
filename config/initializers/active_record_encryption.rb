# ActiveRecord Encryption keys for at-rest encryption of secrets (e.g. storage
# connection access keys). Self-host friendly: keys come from the environment so
# operators set them without editing Rails credentials. In development/test we
# derive deterministic keys from secret_key_base so the app boots with zero setup
# (those environments never hold real cloud secrets).
Rails.application.configure do
  enc = config.active_record.encryption
  base = Rails.application.secret_key_base.to_s

  enc.primary_key         = ENV["AR_ENCRYPTION_PRIMARY_KEY"]         || base[0, 32]
  enc.deterministic_key   = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]   || base[32, 32]
  enc.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"] || base[64, 32]

  # Lets existing NULL/plaintext rows read back while we roll encryption out.
  enc.support_unencrypted_data = true
end
