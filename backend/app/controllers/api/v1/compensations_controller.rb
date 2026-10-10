module Api
  module V1
    # An employee's salary history (HR manager only). Changes go through Compensations::RecordChange.
    class CompensationsController < BaseController
      require_permission :manage_employees

      def index
        employee = Employee.find(params[:employee_id])
        render json: { data: CompensationSerializer.history(employee.compensations.to_a) }
      end

      def create
        attributes = params.require(:compensation).permit(:amount, :currency, :effective_from, :reason, :notes)
        result = Compensations::RecordChange.call(employee_id: params[:employee_id], attributes:)
        return render_validation_errors(result.errors) unless result.success?

        previous = result.compensation.employee.compensations.where(effective_from: ...result.compensation.effective_from)
                         .order(effective_from: :desc).first
        render json: { data: CompensationSerializer.record(result.compensation, previous:) }, status: :created
      end
    end
  end
end
