class ApplicationController < ActionController::API
  include ActionController::Cookies

  private

  # Consistent JSON errors: { "error": { "code": "...", "message": "...", "details": { "field": ["..."] } } }
  def render_error(status, code, message, details = {})
    render json: { error: { code: code, message: message, details: details } }, status: status
  end
end
