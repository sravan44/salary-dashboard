module Compensations
  # Records a pay change without losing history: inside one transaction it locks the employee row
  # (so two changes for the same person run one after the other), checks the new record against the
  # current one, closes the current record the day before the new one starts, and inserts the new
  # one. Any failure rolls everything back; nothing is ever overwritten or deleted.
  class RecordChange
    CHANGE_REASONS = %w[annual_review promotion market_adjustment correction].freeze

    Result = Data.define(:compensation, :errors) do
      def success? = errors.empty?
    end

    def self.call(employee_id:, attributes:) = new(employee_id, attributes).call

    def initialize(employee_id, attributes)
      @employee_id = employee_id
      @attributes = attributes.to_h.symbolize_keys
    end

    def call
      Compensation.transaction do
        employee = Employee.lock.find(@employee_id)
        current = employee.compensations.current.first
        record = build(employee)
        errors = errors_for(employee, current, record)
        next Result.new(compensation: record, errors:) if errors.any?

        current&.update!(effective_to: record.effective_from - 1)
        Result.new(compensation: Compensation.create!(record.attributes.compact), errors: {})
      end
    end

    private

    def build(employee)
      Compensation.new(employee:, amount: @attributes[:amount], currency: @attributes[:currency],
                       effective_from: @attributes[:effective_from], reason: @attributes[:reason].presence,
                       notes: @attributes[:notes].presence, revised_by: Current.actor)
    end

    def errors_for(employee, current, record)
      record.valid?
      # The reason is checked here rather than by the model, whose list also allows "hire".
      errors = record.errors.to_hash.slice(:amount, :currency, :effective_from, :notes).transform_keys(&:to_s)
      errors["reason"] = [ "must be one of: #{CHANGE_REASONS.join(', ')}" ] unless CHANGE_REASONS.include?(record.reason)
      errors.merge!(date_errors(current, record.effective_from))
      errors["employee"] = [ "is deactivated; reactivate them before recording a pay change" ] if employee.terminated?
      errors
    end

    def date_errors(current, date)
      return {} if date.nil? # already "can't be blank"
      return { "effective_from" => [ "can't be in the future" ] } if date.future?
      return {} if current.nil? || date > current.effective_from

      { "effective_from" => [ "must be after the current salary's start date (#{current.effective_from.iso8601})" ] }
    end
  end
end
