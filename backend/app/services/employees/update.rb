module Employees
  # Edits an employee's profile and status (deactivate = "terminated", reactivate = "active").
  # The record is never deleted, and salary history is never touched here: the hire date starts
  # that history, and pay changes are recorded as new salary records (M5).
  class Update
    EDITABLE_FIELDS = %i[full_name email country_code department job_title status].freeze
    LOCKED_FIELDS = {
      hire_date: "cannot be changed after the employee is created",
      employee_number: "cannot be changed after the employee is created",
      salary: "is changed by recording a salary change, not by editing the employee"
    }.freeze

    Result = Create::Result

    def self.call(employee, attributes) = new(employee, attributes).call

    def initialize(employee, attributes)
      @employee = employee
      @attributes = attributes.to_h.symbolize_keys
    end

    def call
      locked = LOCKED_FIELDS.slice(*@attributes.keys).to_h { |field, message| [ field.to_s, [ message ] ] }
      return failure(locked) if locked.any?

      @employee.assign_attributes(@attributes.slice(*EDITABLE_FIELDS))
      return failure(@employee.errors.to_hash.transform_keys(&:to_s)) unless @employee.save

      Result.new(employee: @employee, errors: {})
    rescue ActiveRecord::RecordNotUnique
      failure("email" => [ "has already been taken" ])
    end

    private

    def failure(errors) = Result.new(employee: @employee, errors:)
  end
end
