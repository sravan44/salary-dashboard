class CreateCompensations < ActiveRecord::Migration[8.1]
  def change
    create_table :compensations do |t|
      t.references :employee, null: false, foreign_key: true
      t.decimal :amount, null: false, precision: 14, scale: 2 # annual base salary, never a float
      t.string :currency, null: false, limit: 3                # ISO-4217
      t.date :effective_from, null: false
      t.date :effective_to                                     # NULL = current
      t.string :reason, null: false                            # why the salary changed
      t.string :revised_by                                     # who recorded it (user reference from M7)
      t.text :notes
      t.timestamps
    end

    # At most one current salary per employee, guaranteed by the database even under concurrent writes.
    add_index :compensations, :employee_id, unique: true, where: "effective_to IS NULL",
                                            name: "index_compensations_one_current_per_employee"
    add_index :compensations, [ :employee_id, :effective_from ], unique: true

    add_check_constraint :compensations, "amount > 0", name: "compensations_amount_positive"
    add_check_constraint :compensations, "effective_to IS NULL OR effective_to >= effective_from",
                         name: "compensations_dates_ordered"
    add_check_constraint :compensations,
                         "reason IN ('hire', 'annual_review', 'promotion', 'market_adjustment', 'correction')",
                         name: "compensations_reason_known"
  end
end
