module Api
  module V1
    # An employee's salary history (HR manager only). Changes go through Compensations::RecordChange.
    class CompensationsController < BaseController
      require_permission :manage_employees

      # ?report=USD adds each record's amount in that currency, plus the rates used (indicative).
      def index
        employee = Employee.find(params[:employee_id])
        records = employee.compensations.to_a
        return render json: { data: CompensationSerializer.history(records) } if params[:report].blank?

        conversion = Fx::Conversion.new(to: reporting_currency)
        render json: { data: CompensationSerializer.history(records, conversion:),
                       meta: { conversion: conversion.details(records.map(&:currency)) } }
      end

      def create
        attributes = params.require(:compensation).permit(:amount, :currency, :effective_from, :reason, :notes)
        result = Compensations::RecordChange.call(employee_id: params[:employee_id], attributes:)
        return render_validation_errors(result.errors) unless result.success?

        previous = result.compensation.employee.compensations.where(effective_from: ...result.compensation.effective_from)
                         .order(effective_from: :desc).first
        render json: { data: CompensationSerializer.record(result.compensation, previous:) }, status: :created
      end

      private

      def reporting_currency
        currency = params[:report].to_s
        return currency if Acme::Reference.currencies.include?(currency)

        raise Employees::DirectoryQuery::InvalidParams, { report: [ "must be one of: #{Acme::Reference.currencies.join(', ')}" ] }
      end
    end
  end
end
