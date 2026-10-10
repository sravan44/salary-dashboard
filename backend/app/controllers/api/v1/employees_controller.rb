module Api
  module V1
    class EmployeesController < BaseController
      SINGLE_PARAMS = %i[q currency min_salary max_salary sort page per_page].freeze
      # Accepted as one value (country=DE) or several (country[]=DE&country[]=FR).
      LIST_PARAMS = %i[country department job_title status].freeze

      def index
        permitted = params.permit(*SINGLE_PARAMS, *LIST_PARAMS, **LIST_PARAMS.index_with { [] })
        result = Employees::DirectoryQuery.new(permitted).call
        render json: {
          data: result.records.map { |employee| EmployeeSerializer.summary(employee) },
          meta: { page: result.page, per_page: result.per_page, total: result.total, total_pages: result.total_pages }
        }
      end

      def show
        employee = Employee.includes(:current_compensation).find(params[:id])
        render json: { data: EmployeeSerializer.detail(employee) }
      end
    end
  end
end
