# Signing in for request specs goes through the real endpoint, so every spec exercises the
# same cookie and session path the browser uses.
module AuthHelpers
  PASSWORD = "correct horse battery".freeze

  def sign_in_as(*roles, email: "#{roles.join('-')}@acme.example")
    user = User.find_by(email:) || create(:user, email:, roles: roles.map(&:to_s), password: PASSWORD)
    post "/api/v1/session", params: { email:, password: PASSWORD }, as: :json
    raise "sign-in failed with #{response.status}" unless response.status == 201

    user
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  # The login rate limit counts per IP across requests; each example starts with a clean count.
  config.before do
    Api::V1::SessionsController::RATE_LIMIT_STORE.clear
    Api::V1::PasswordResetsController::RATE_LIMIT_STORE.clear
    Api::V1::ExchangeRatesController::RATE_LIMIT_STORE.clear
  end
end
