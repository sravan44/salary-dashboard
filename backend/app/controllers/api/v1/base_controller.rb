module Api
  module V1
    # Consistent JSON errors for every API endpoint:
    # { "error": { "code": "...", "message": "...", "details": { "field": ["..."] } } }
    class BaseController < ApplicationController
      include Authentication

      allow_signed_out only: :route_not_found

      rescue_from ActiveRecord::RecordNotFound do
        render_error(:not_found, "not_found", "Record not found")
      end

      rescue_from ActionController::ParameterMissing do |error|
        render_error(:bad_request, "invalid_parameters", "Missing parameter: #{error.param}", { error.param => [ "is required" ] })
      end

      rescue_from Employees::DirectoryQuery::InvalidParams do |error|
        render_error(:bad_request, "invalid_parameters", "Some query parameters are invalid", error.details)
      end

      def route_not_found
        render_error(:not_found, "not_found", "No such API endpoint")
      end

      private

      def render_validation_errors(details)
        render_error(:unprocessable_content, "validation_failed", "Some fields are invalid", details)
      end
    end
  end
end
