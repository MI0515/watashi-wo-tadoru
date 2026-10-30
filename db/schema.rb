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

ActiveRecord::Schema[8.1].define(version: 2026_10_30_051127) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companions", force: :cascade do |t|
    t.bigint "personality_type_id", null: false
    t.string "appearance_type", null: false
    t.string "sd_image_path", null: false
    t.string "full_image_path", null: false
    t.string "speaking_style", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["personality_type_id", "appearance_type"], name: "index_companions_on_personality_type_id_and_appearance_type", unique: true
    t.index ["personality_type_id"], name: "index_companions_on_personality_type_id"
  end

  create_table "personality_types", force: :cascade do |t|
    t.string "code", null: false
    t.string "group_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_personality_types_on_code", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "nickname"
    t.string "honorific"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "personality_type_id"
    t.bigint "companion_id"
    t.index ["companion_id"], name: "index_users_on_companion_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["personality_type_id"], name: "index_users_on_personality_type_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "companions", "personality_types"
  add_foreign_key "users", "companions"
  add_foreign_key "users", "personality_types"
end
