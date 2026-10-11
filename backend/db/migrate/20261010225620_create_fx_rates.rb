# Cached reference exchange rates, one row per (base, quote, rate date). Conversion reads only this
# table, never the provider, so the dashboard stays fast and reproducible, and every converted figure
# can name the exact rate, date and source it used.
class CreateFxRates < ActiveRecord::Migration[8.1]
  def change
    create_table :fx_rates do |t|
      t.string :base, limit: 3, null: false
      t.string :quote, limit: 3, null: false
      t.date :rate_date, null: false
      t.decimal :rate, precision: 20, scale: 10, null: false
      t.string :source, null: false
      t.datetime :fetched_at, null: false
      t.timestamps
    end
    add_index :fx_rates, %i[base quote rate_date], unique: true
    add_check_constraint :fx_rates, "rate > 0", name: "fx_rates_rate_positive"
  end
end
