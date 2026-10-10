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

ActiveRecord::Schema[8.1].define(version: 2026_10_10_085546) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "compensations", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.string "currency", limit: 3, null: false
    t.date "effective_from", null: false
    t.date "effective_to"
    t.string "reason", null: false
    t.string "revised_by"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_from"], name: "index_compensations_on_employee_id_and_effective_from", unique: true
    t.index ["employee_id"], name: "index_compensations_on_employee_id"
    t.index ["employee_id"], name: "index_compensations_one_current_per_employee", unique: true, where: "(effective_to IS NULL)"
    t.check_constraint "amount > 0::numeric", name: "compensations_amount_positive"
    t.check_constraint "effective_to IS NULL OR effective_to >= effective_from", name: "compensations_dates_ordered"
    t.check_constraint "reason::text = ANY (ARRAY['hire'::character varying, 'annual_review'::character varying, 'promotion'::character varying, 'market_adjustment'::character varying, 'correction'::character varying]::text[])", name: "compensations_reason_known"
  end

  create_table "employees", force: :cascade do |t|
    t.string "employee_number", null: false
    t.string "full_name", null: false
    t.string "email", null: false
    t.string "country_code", limit: 2, null: false
    t.string "department", null: false
    t.string "job_title", null: false
    t.string "status", default: "active", null: false
    t.date "hire_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["employee_number"], name: "index_employees_on_employee_number", unique: true
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'terminated'::character varying]::text[])", name: "employees_status_known"
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.jsonb "object_changes", default: {}, null: false
    t.string "whodunnit"
    t.datetime "created_at", null: false
    t.index ["item_type", "item_id", "id"], name: "index_versions_on_item_type_and_item_id_and_id"
    t.check_constraint "event::text = ANY (ARRAY['create'::character varying, 'update'::character varying]::text[])", name: "versions_event_known"
  end

  add_foreign_key "compensations", "employees"
end
