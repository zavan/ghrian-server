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

ActiveRecord::Schema[8.1].define(version: 2026_06_09_180234) do
  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name"
    t.string "token"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "daily_summaries", force: :cascade do |t|
    t.float "charge_kwh", default: 0.0, null: false
    t.float "consumption_kwh", default: 0.0, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.float "discharge_kwh", default: 0.0, null: false
    t.float "feed_in_kwh", default: 0.0, null: false
    t.float "generation_kwh", default: 0.0, null: false
    t.float "import_kwh", default: 0.0, null: false
    t.integer "inverter_id", null: false
    t.datetime "updated_at", null: false
    t.index ["inverter_id", "date"], name: "index_daily_summaries_on_inverter_id_and_date", unique: true
  end

  create_table "inverters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_model"
    t.datetime "last_reading_at"
    t.datetime "last_seen_at"
    t.json "latest_values"
    t.string "mqtt_topic"
    t.string "name"
    t.string "serial_number"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["mqtt_topic"], name: "index_inverters_on_mqtt_topic", unique: true
  end

  create_table "mqtt_configs", force: :cascade do |t|
    t.string "base_topic", default: "ghrian", null: false
    t.string "client_id"
    t.datetime "created_at", null: false
    t.string "host", default: "localhost", null: false
    t.text "password"
    t.integer "port", default: 1883, null: false
    t.datetime "updated_at", null: false
    t.boolean "use_tls", default: false, null: false
    t.string "username"
  end

  create_table "readings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "data"
    t.string "device_model"
    t.integer "inverter_id", null: false
    t.datetime "recorded_at"
    t.datetime "updated_at", null: false
    t.index ["inverter_id", "recorded_at"], name: "index_readings_on_inverter_id_and_recorded_at"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tariffs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "$", null: false
    t.decimal "export_rate", precision: 10, scale: 4, default: "0.0", null: false
    t.decimal "import_rate", precision: 10, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "api_tokens", "users"
  add_foreign_key "daily_summaries", "inverters"
  add_foreign_key "readings", "inverters"
  add_foreign_key "sessions", "users"
end
