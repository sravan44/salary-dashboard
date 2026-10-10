class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.string :employee_number, null: false
      t.string :full_name, null: false
      t.string :email, null: false
      t.string :country_code, null: false, limit: 2
      t.string :department, null: false
      t.string :job_title, null: false
      t.string :status, null: false, default: "active"
      t.date :hire_date, null: false
      t.timestamps
    end

    add_index :employees, :employee_number, unique: true
    add_index :employees, :email, unique: true # stored lower-cased by the model
    add_check_constraint :employees, "status IN ('active', 'terminated')", name: "employees_status_known"
    # Filter/sort indexes are added in M8, only where EXPLAIN on the 10k seed justifies them.
  end
end
