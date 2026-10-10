# Plain-Ruby JSON shapes for employees (see docs/api-contract.md).
# Expects `current_amount` / `current_currency` to be selected by Employees::DirectoryQuery,
# or falls back to the employee's current compensation.
module EmployeeSerializer
  module_function

  def summary(employee)
    {
      id: employee.id,
      employee_number: employee.employee_number,
      full_name: employee.full_name,
      country_code: employee.country_code,
      department: employee.department,
      job_title: employee.job_title,
      status: employee.status,
      hire_date: employee.hire_date.iso8601,
      current_salary: current_salary(employee)
    }
  end

  def detail(employee)
    summary(employee).merge(email: employee.email)
  end

  def current_salary(employee)
    amount, currency =
      if employee.has_attribute?(:current_amount)
        [ employee.current_amount, employee.current_currency ]
      else
        employee.current_compensation&.then { |c| [ c.amount, c.currency ] }
      end
    return nil if amount.nil?

    { amount: Money.format_amount(amount), currency: currency }
  end
end
