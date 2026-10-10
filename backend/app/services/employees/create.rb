module Employees
  # Hires an employee: the profile and their first salary (reason "hire", starting on the hire date)
  # are saved together in one transaction, or not at all. The employee number is assigned here,
  # under a transaction-scoped advisory lock, so two creates at the same moment never share a number.
  class Create
    PROFILE_FIELDS = %i[full_name email country_code department job_title hire_date].freeze
    NUMBER_LOCK_KEY = 7_311_001 # arbitrary, app-wide constant for pg_advisory_xact_lock
    MAX_NUMBER = 999_999

    Result = Data.define(:employee, :errors) do
      def success? = errors.empty?
    end

    def self.call(attributes) = new(attributes).call

    def initialize(attributes)
      @attributes = attributes.to_h.deep_symbolize_keys
    end

    def call
      employee = build
      errors = errors_for(employee)
      return Result.new(employee:, errors:) if errors.any?

      Employee.transaction do
        Employee.connection.execute("SELECT pg_advisory_xact_lock(#{NUMBER_LOCK_KEY})")
        employee.employee_number = next_number
        employee.save!
      end
      Result.new(employee:, errors: {})
    rescue ActiveRecord::RecordInvalid
      # Report what failed at save time (e.g. an email taken a moment ago); re-validating after the
      # rollback could find nothing wrong and wrongly look like success.
      Result.new(employee:, errors: formatted_errors(employee))
    rescue ActiveRecord::RecordNotUnique
      # Only the email can clash here (numbers are assigned under the lock).
      Result.new(employee:, errors: { "email" => [ "has already been taken" ] })
    end

    private

    def build
      salary = @attributes[:salary] || {}
      Employee.new(@attributes.slice(*PROFILE_FIELDS).merge(status: "active")).tap do |employee|
        employee.compensations.build(amount: salary[:amount], currency: salary[:currency],
                                     effective_from: employee.hire_date, reason: "hire")
      end
    end

    def errors_for(employee)
      employee.valid?
      employee.compensations.first.valid?
      employee.errors.add(:hire_date, "can't be in the future") if employee.hire_date&.future?
      formatted_errors(employee)
    end

    def formatted_errors(employee)
      compensation = employee.compensations.first
      # The number is assigned under the lock just before saving, so it is not the caller's to fix.
      profile = employee.errors.to_hash.except(:compensations, :employee_number).transform_keys(&:to_s)
      salary = compensation.errors.to_hash.slice(:amount, :currency).transform_keys { |key| "salary.#{key}" }
      profile.merge(salary)
    end

    def next_number
      last = Employee.maximum(:employee_number)&.delete_prefix("EMP-").to_i || 0
      raise "Employee numbers exhausted" if last >= MAX_NUMBER

      format("EMP-%06d", last + 1)
    end
  end
end
