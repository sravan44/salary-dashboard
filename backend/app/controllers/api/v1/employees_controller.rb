module Api
  module V1
    class EmployeesController < BaseController
      DIRECTORY_PARAMS = %i[q country department job_title status currency min_salary max_salary sort page per_page].freeze

      def index
        result = Employees::DirectoryQuery.new(params.permit(*DIRECTORY_PARAMS)).call
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
