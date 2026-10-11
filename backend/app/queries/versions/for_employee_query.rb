module Versions
  # The audit trail of one employee and their salary records, newest first.
  # Written as UNION ALL of two lookups so each uses the (item_type, item_id, id) index; the
  # equivalent `WHERE … OR …` made PostgreSQL walk the whole (ever-growing) log backwards.
  class ForEmployeeQuery
    def initialize(employee)
      @employee = employee
    end

    def call
      own = Version.where(item_type: "Employee", item_id: @employee.id)
      salary = Version.where(item_type: "Compensation", item_id: Compensation.where(employee_id: @employee.id).select(:id))
      Version.from("(#{own.to_sql} UNION ALL #{salary.to_sql}) AS versions").order(id: :desc)
    end
  end
end
