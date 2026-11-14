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

ActiveRecord::Schema[8.1].define(version: 2026_11_14_063405) do
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

  create_table "emotions", force: :cascade do |t|
    t.string "name", null: false
    t.integer "display_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_emotions_on_name", unique: true
  end

  create_table "monologues", force: :cascade do |t|
    t.bigint "personality_type_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["personality_type_id"], name: "index_monologues_on_personality_type_id"
  end

  create_table "personality_types", force: :cascade do |t|
    t.string "code", null: false
    t.string "group_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_personality_types_on_code", unique: true
  end

  create_table "reflection_emotions", force: :cascade do |t|
    t.bigint "reflection_id", null: false
    t.bigint "emotion_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["emotion_id"], name: "index_reflection_emotions_on_emotion_id"
    t.index ["reflection_id", "emotion_id"], name: "index_reflection_emotions_on_reflection_id_and_emotion_id", unique: true
    t.index ["reflection_id"], name: "index_reflection_emotions_on_reflection_id"
  end

  create_table "reflection_messages", force: :cascade do |t|
    t.bigint "reflection_id", null: false
    t.integer "role", null: false
    t.text "content", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reflection_id", "position"], name: "index_reflection_messages_on_reflection_id_and_position", unique: true
    t.index ["reflection_id"], name: "index_reflection_messages_on_reflection_id"
  end

  create_table "reflections", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "companion_id", null: false
    t.text "initial_text", null: false
    t.string "title"
    t.text "valued_thing"
    t.text "insight"
    t.text "personal_note"
    t.integer "status", default: 0, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["companion_id"], name: "index_reflections_on_companion_id"
    t.index ["user_id"], name: "index_reflections_on_user_id"
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
    t.datetime "onboarding_completed_at"
    t.index ["companion_id"], name: "index_users_on_companion_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["personality_type_id"], name: "index_users_on_personality_type_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "companions", "personality_types"
  add_foreign_key "monologues", "personality_types"
  add_foreign_key "reflection_emotions", "emotions", on_delete: :restrict
  add_foreign_key "reflection_emotions", "reflections", on_delete: :cascade
  add_foreign_key "reflection_messages", "reflections", on_delete: :cascade
  add_foreign_key "reflections", "companions", on_delete: :restrict
  add_foreign_key "reflections", "users", on_delete: :cascade
  add_foreign_key "users", "companions"
  add_foreign_key "users", "personality_types"
end
