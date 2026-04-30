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

ActiveRecord::Schema[7.2].define(version: 2026_05_01_000010) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "auto_schedule_rules", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.integer "max_days_per_week"
    t.integer "min_days_per_week"
    t.integer "deprioritized_days", default: [], array: true
    t.integer "excluded_days", default: [], array: true
    t.integer "week_start_day", default: 1
    t.integer "confirm_days_before", default: 3
    t.integer "remind_days_before_confirm", default: 2
    t.time "confirm_time", default: "2000-01-01 21:00:00"
    t.integer "activity_notify_hours_before", default: 8
    t.string "activity_notify_channel_id"
    t.text "activity_notify_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_auto_schedule_rules_on_group_id"
  end

  create_table "availabilities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "group_id", null: false
    t.date "date", null: false
    t.integer "status"
    t.text "comment"
    t.boolean "auto_synced", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_availabilities_on_group_id"
    t.index ["user_id", "group_id", "date"], name: "idx_availabilities_user_group_date", unique: true
    t.index ["user_id"], name: "index_availabilities_on_user_id"
  end

  create_table "availability_logs", force: :cascade do |t|
    t.bigint "availability_id", null: false
    t.bigint "user_id", null: false
    t.integer "old_status"
    t.integer "new_status"
    t.text "old_comment"
    t.text "new_comment"
    t.text "user_agent"
    t.inet "ip_address"
    t.string "geo_region"
    t.datetime "created_at", null: false
    t.index ["availability_id"], name: "index_availability_logs_on_availability_id"
    t.index ["user_id"], name: "index_availability_logs_on_user_id"
  end

  create_table "calendar_caches", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "group_id", null: false
    t.date "date", null: false
    t.boolean "has_event"
    t.datetime "fetched_at"
    t.index ["group_id"], name: "index_calendar_caches_on_group_id"
    t.index ["user_id", "group_id", "date"], name: "idx_calendar_caches_user_group_date", unique: true
    t.index ["user_id"], name: "index_calendar_caches_on_user_id"
  end

  create_table "discord_configs", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.string "guild_id"
    t.string "default_channel_id"
    t.string "remind_channel_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_discord_configs_on_group_id", unique: true
  end

  create_table "event_days", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.date "date", null: false
    t.time "start_time"
    t.time "end_time"
    t.boolean "auto_generated", default: false
    t.boolean "confirmed", default: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "date"], name: "index_event_days_on_group_id_and_date", unique: true
    t.index ["group_id"], name: "index_event_days_on_group_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.string "event_name"
    t.bigint "owner_id", null: false
    t.string "share_token", null: false
    t.string "timezone", default: "Asia/Tokyo"
    t.time "default_start_time"
    t.time "default_end_time"
    t.integer "threshold_n"
    t.string "threshold_target", default: "core"
    t.boolean "ad_enabled", default: true
    t.string "locale", default: "ja"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_groups_on_owner_id"
    t.index ["share_token"], name: "index_groups_on_share_token", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "group_id", null: false
    t.string "role", default: "sub"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_memberships_on_group_id"
    t.index ["user_id", "group_id"], name: "index_memberships_on_user_id_and_group_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.text "user_agent"
    t.inet "ip_address"
    t.datetime "created_at", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "discord_user_id"
    t.string "discord_screen_name"
    t.string "display_name"
    t.string "google_account_id"
    t.text "google_oauth_token"
    t.string "google_calendar_scope"
    t.boolean "auth_locked", default: false
    t.string "locale", default: "ja"
    t.boolean "anonymized", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discord_user_id"], name: "index_users_on_discord_user_id", unique: true
    t.index ["google_account_id"], name: "index_users_on_google_account_id", unique: true
  end

  add_foreign_key "auto_schedule_rules", "groups"
  add_foreign_key "availabilities", "groups"
  add_foreign_key "availabilities", "users"
  add_foreign_key "availability_logs", "availabilities"
  add_foreign_key "availability_logs", "users"
  add_foreign_key "calendar_caches", "groups"
  add_foreign_key "calendar_caches", "users"
  add_foreign_key "discord_configs", "groups"
  add_foreign_key "event_days", "groups"
  add_foreign_key "groups", "users", column: "owner_id"
  add_foreign_key "memberships", "groups"
  add_foreign_key "memberships", "users"
  add_foreign_key "sessions", "users"
end
