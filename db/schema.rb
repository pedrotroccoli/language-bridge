# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_28_020600) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_tokens", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "creator_id"
    t.datetime "last_used_at"
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.datetime "revoked_at"
    t.string "scope", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_api_tokens_on_creator_id"
    t.index ["project_id"], name: "index_api_tokens_on_project_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "events", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id"
    t.uuid "eventable_id", null: false
    t.string "eventable_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_events_on_created_at"
    t.index ["creator_id", "created_at"], name: "index_events_on_creator_id_and_created_at"
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable_type_and_eventable_id"
  end

  create_table "invitations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.uuid "inviter_id", null: false
    t.string "role", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_invitations_on_email", unique: true, where: "(accepted_at IS NULL)"
    t.index ["inviter_id"], name: "index_invitations_on_inviter_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "locales", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.uuid "project_id", null: false
    t.integer "translations_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "code"], name: "index_locales_on_project_id_and_code", unique: true
    t.index ["project_id"], name: "index_locales_on_project_id"
  end

  create_table "missing_key_reports", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "first_reported_at"
    t.integer "hits", default: 0, null: false
    t.string "key", null: false
    t.datetime "last_reported_at"
    t.jsonb "locales", default: [], null: false
    t.string "namespace", null: false
    t.uuid "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "last_reported_at"], name: "index_missing_key_reports_on_project_id_and_last_reported_at"
    t.index ["project_id", "namespace", "key"], name: "index_missing_key_reports_on_project_id_and_namespace_and_key", unique: true
    t.index ["project_id"], name: "index_missing_key_reports_on_project_id"
  end

  create_table "namespaces", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.integer "translation_keys_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_namespaces_on_project_id_and_name", unique: true
  end

  create_table "project_backups", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.bigint "byte_size", default: 0, null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.uuid "project_id", null: false
    t.string "source", default: "manual", null: false
    t.integer "translations_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "created_at"], name: "index_project_backups_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_project_backups_on_project_id"
  end

  create_table "projects", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "backup_frequency", default: "daily", null: false
    t.boolean "backup_include_drafts", default: false, null: false
    t.integer "backup_retention", default: 30, null: false
    t.boolean "backups_enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.string "delivery_path_template", default: "{project_slug}/{namespace}/{locale}.json", null: false
    t.integer "delivery_rate_limit"
    t.integer "locales_count", default: 0, null: false
    t.integer "missing_rate_limit"
    t.string "name", null: false
    t.integer "namespaces_count", default: 0, null: false
    t.string "slug", null: false
    t.integer "translation_keys_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_projects_on_slug", unique: true
  end

  create_table "sessions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "delivery_rate_limit", default: 300, null: false
    t.integer "delivery_rate_period", default: 60, null: false
    t.integer "missing_rate_limit", default: 30, null: false
    t.integer "missing_rate_period", default: 60, null: false
    t.boolean "rate_limiting_enabled", default: true, null: false
    t.datetime "updated_at", null: false
  end

  create_table "sign_in_tokens", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["token"], name: "index_sign_in_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_sign_in_tokens_on_user_id"
  end

  create_table "storage_connections", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "bucket"
    t.datetime "created_at", null: false
    t.boolean "is_default", default: false, null: false
    t.string "name", null: false
    t.string "region"
    t.string "service_name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "translation_approvals", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "approver_id", null: false
    t.datetime "created_at", null: false
    t.uuid "translation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_translation_approvals_on_approver_id"
    t.index ["translation_id"], name: "index_translation_approvals_on_translation_id", unique: true
  end

  create_table "translation_artifacts", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "built_at", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.uuid "locale_id", null: false
    t.uuid "namespace_id", null: false
    t.uuid "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["locale_id"], name: "index_translation_artifacts_on_locale_id"
    t.index ["namespace_id", "locale_id"], name: "index_translation_artifacts_on_namespace_id_and_locale_id", unique: true
    t.index ["namespace_id"], name: "index_translation_artifacts_on_namespace_id"
    t.index ["project_id"], name: "index_translation_artifacts_on_project_id"
  end

  create_table "translation_keys", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.uuid "namespace_id", null: false
    t.uuid "project_id", null: false
    t.integer "translations_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["namespace_id"], name: "index_translation_keys_on_namespace_id"
    t.index ["project_id", "namespace_id", "key"], name: "index_translation_keys_on_project_id_and_namespace_id_and_key", unique: true
    t.index ["project_id"], name: "index_translation_keys_on_project_id"
  end

  create_table "translation_publications", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "publisher_id"
    t.uuid "translation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["publisher_id"], name: "index_translation_publications_on_publisher_id"
    t.index ["translation_id"], name: "index_translation_publications_on_translation_id", unique: true
  end

  create_table "translation_reviews", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "requester_id", null: false
    t.uuid "translation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["requester_id"], name: "index_translation_reviews_on_requester_id"
    t.index ["translation_id"], name: "index_translation_reviews_on_translation_id", unique: true
  end

  create_table "translation_versions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "author_id"
    t.datetime "created_at", null: false
    t.uuid "translation_id", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["author_id"], name: "index_translation_versions_on_author_id"
    t.index ["translation_id", "created_at"], name: "index_translation_versions_on_translation_id_and_created_at"
    t.index ["translation_id"], name: "index_translation_versions_on_translation_id"
  end

  create_table "translations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "author_id"
    t.datetime "created_at", null: false
    t.uuid "locale_id", null: false
    t.uuid "project_id", null: false
    t.uuid "translation_key_id", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["author_id"], name: "index_translations_on_author_id"
    t.index ["locale_id"], name: "index_translations_on_locale_id"
    t.index ["project_id"], name: "index_translations_on_project_id"
    t.index ["translation_key_id", "locale_id"], name: "index_translations_on_translation_key_id_and_locale_id", unique: true
  end

  create_table "users", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "role", default: "translator", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "projects"
  add_foreign_key "api_tokens", "users", column: "creator_id", on_delete: :nullify
  add_foreign_key "events", "users", column: "creator_id"
  add_foreign_key "invitations", "users", column: "inviter_id"
  add_foreign_key "locales", "projects"
  add_foreign_key "missing_key_reports", "projects"
  add_foreign_key "namespaces", "projects"
  add_foreign_key "project_backups", "projects"
  add_foreign_key "sessions", "users"
  add_foreign_key "sign_in_tokens", "users"
  add_foreign_key "translation_approvals", "translations"
  add_foreign_key "translation_approvals", "users", column: "approver_id"
  add_foreign_key "translation_artifacts", "locales"
  add_foreign_key "translation_artifacts", "namespaces"
  add_foreign_key "translation_artifacts", "projects"
  add_foreign_key "translation_keys", "namespaces"
  add_foreign_key "translation_keys", "projects"
  add_foreign_key "translation_publications", "translations"
  add_foreign_key "translation_publications", "users", column: "publisher_id"
  add_foreign_key "translation_reviews", "translations"
  add_foreign_key "translation_reviews", "users", column: "requester_id"
  add_foreign_key "translation_versions", "translations"
  add_foreign_key "translation_versions", "users", column: "author_id"
  add_foreign_key "translations", "locales"
  add_foreign_key "translations", "projects"
  add_foreign_key "translations", "translation_keys"
  add_foreign_key "translations", "users", column: "author_id"
end
