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

ActiveRecord::Schema[8.1].define(version: 2026_08_14_175639) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
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

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "coin_transactions", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.integer "transaction_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_coin_transactions_on_user_id"
  end

  create_table "episode_unlocks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "episode_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["episode_id"], name: "index_episode_unlocks_on_episode_id"
    t.index ["user_id", "episode_id"], name: "index_episode_unlocks_on_user_id_and_episode_id", unique: true
    t.index ["user_id"], name: "index_episode_unlocks_on_user_id"
  end

  create_table "episodes", force: :cascade do |t|
    t.integer "coin_cost", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration"
    t.integer "episode_number"
    t.boolean "locked", default: false, null: false
    t.string "mux_asset_id"
    t.string "mux_playback_id"
    t.string "mux_upload_id"
    t.string "published_at"
    t.datetime "scheduled_at"
    t.bigint "series_id", null: false
    t.string "thumbnail"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "video_status", default: 0, null: false
    t.index ["mux_asset_id"], name: "index_episodes_on_mux_asset_id", unique: true
    t.index ["mux_playback_id"], name: "index_episodes_on_mux_playback_id", unique: true
    t.index ["mux_upload_id"], name: "index_episodes_on_mux_upload_id", unique: true
    t.index ["series_id", "episode_number"], name: "index_episodes_on_series_id_and_episode_number", unique: true
    t.index ["series_id"], name: "index_episodes_on_series_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp"
    t.string "jti"
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "series", force: :cascade do |t|
    t.string "banner_image"
    t.string "cover_image"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "genre"
    t.boolean "is_published", default: false, null: false
    t.datetime "release_date"
    t.integer "status"
    t.string "thumbnail"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.string "plan", default: "monthly", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.string "stripe_price_id"
    t.string "stripe_subscription_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["user_id", "status"], name: "index_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "coin_balance", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.string "stripe_customer_id"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id"
  end

  create_table "watch_progresses", force: :cascade do |t|
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "episode_id", null: false
    t.integer "progress_seconds", default: 0, null: false
    t.bigint "series_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["episode_id"], name: "index_watch_progresses_on_episode_id"
    t.index ["series_id"], name: "index_watch_progresses_on_series_id"
    t.index ["user_id", "episode_id"], name: "index_watch_progresses_on_user_id_and_episode_id", unique: true
    t.index ["user_id", "series_id"], name: "index_watch_progresses_on_user_id_and_series_id"
    t.index ["user_id"], name: "index_watch_progresses_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "coin_transactions", "users"
  add_foreign_key "episode_unlocks", "episodes"
  add_foreign_key "episode_unlocks", "users"
  add_foreign_key "episodes", "series"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "watch_progresses", "episodes"
  add_foreign_key "watch_progresses", "series"
  add_foreign_key "watch_progresses", "users"
end
