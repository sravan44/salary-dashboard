module Api
  module V1
    # The audit trail for one employee and their salary records, newest first (HR manager only).
    class VersionsController < BaseController
      require_permission :manage_employees

      def index
        employee = Employee.find(params[:employee_id])
        versions = Version.where(item: employee)
                          .or(Version.where(item_type: "Compensation", item_id: employee.compensations.select(:id)))
                          .order(id: :desc)
        render json: { data: versions.map { |version| serialize(version) } }
      end

      private

      def serialize(version)
        { id: version.id, item_type: version.item_type, item_id: version.item_id, event: version.event,
          changes: version.object_changes, whodunnit: version.whodunnit, created_at: version.created_at.iso8601 }
      end
    end
  end
end
