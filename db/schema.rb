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

ActiveRecord::Schema[8.1].define(version: 2026_06_14_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "listings", force: :cascade do |t|
    t.jsonb "ai_cons"
    t.jsonb "ai_pros"
    t.text "ai_summary"
    t.jsonb "amenities"
    t.string "available_date"
    t.boolean "balcony"
    t.decimal "bathrooms"
    t.decimal "bedrooms", precision: 3, scale: 1
    t.string "city"
    t.datetime "created_at", null: false
    t.decimal "distance_km"
    t.integer "drive_minutes"
    t.boolean "favorited", default: false, null: false
    t.string "input_mode"
    t.string "laundry"
    t.string "neighbourhood"
    t.text "notes"
    t.boolean "parking"
    t.string "parking_details"
    t.boolean "pets_allowed"
    t.text "raw_text"
    t.jsonb "red_flags"
    t.integer "rent"
    t.integer "score"
    t.jsonb "score_breakdown"
    t.string "source"
    t.integer "sqft"
    t.string "status", default: "active", null: false
    t.string "street_address"
    t.datetime "updated_at", null: false
    t.string "url"
    t.jsonb "utilities_included"
    t.index ["rent"], name: "index_listings_on_rent"
    t.index ["score"], name: "index_listings_on_score"
    t.index ["status"], name: "index_listings_on_status"
  end
end
