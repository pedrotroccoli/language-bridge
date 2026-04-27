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

ActiveRecord::Schema[8.1].define(version: 2026_04_26_060000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "namespaces", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.integer "translation_keys_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_namespaces_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_namespaces_on_project_id"
  end

  create_table "projects", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "locales_count", default: 0, null: false
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

  create_table "sign_in_tokens", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["token"], name: "index_sign_in_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_sign_in_tokens_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "role", default: "translator", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "invitations", "users", column: "inviter_id"
  add_foreign_key "namespaces", "projects"
  add_foreign_key "sessions", "users"
  add_foreign_key "sign_in_tokens", "users"
end
