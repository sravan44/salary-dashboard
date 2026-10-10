module Api
  module V1
    # Consistent JSON errors for every API endpoint:
    # { "error": { "code": "...", "message": "...", "details": { "field": ["..."] } } }
    class BaseController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound do
        render_error(:not_found, "not_found", "Record not found")
      end

      rescue_from Employees::DirectoryQuery::InvalidParams do |error|
        render_error(:bad_request, "invalid_parameters", "Some query parameters are invalid", error.details)
      end

      private

      def render_error(status, code, message, details = {})
        render json: { error: { code: code, message: message, details: details } }, status: status
      end
    end
  end
end
