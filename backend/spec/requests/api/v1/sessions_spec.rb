require "rails_helper"

RSpec.describe "Sign-in sessions API" do
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) { create(:user, email: "hr@acme.example", roles: %w[hr_manager], password: "correct horse battery") }

  def sign_in(email: "hr@acme.example", password: "correct horse battery")
    post "/api/v1/session", params: { email:, password: }, as: :json
  end

  it "signs in, returns who you are, and sets an HttpOnly, SameSite=Lax session cookie" do
    sign_in

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["data"]).to eq(
      "id" => user.id, "email" => "hr@acme.example", "roles" => %w[hr_manager],
      "permissions" => { "view_dashboard" => true, "manage_employees" => true, "manage_users" => false },
      "email_inbox" => false
    )
    cookie = response.headers["Set-Cookie"]
    expect(cookie).to match(/session_token=/).and match(/httponly/i).and match(/samesite=lax/i)
    expect(cookie).not_to match(/secure/i) # plain http in tests; set when the request is HTTPS
  end

  it "accepts the email in any case" do
    sign_in(email: "  HR@Acme.example ")

    expect(response).to have_http_status(:created)
  end

  it "gives the same answer for a wrong password and an unknown email" do
    sign_in(password: "wrong password!!")
    wrong_password = [ response.status, response.parsed_body ]
    sign_in(email: "nobody@acme.example")

    expect([ response.status, response.parsed_body ]).to eq(wrong_password)
    expect(wrong_password).to eq([ 401, { "error" => { "code" => "invalid_credentials", "message" => "Email or password is incorrect", "details" => {} } } ])
  end

  it "tells who is signed in, and 401 when nobody is" do
    get "/api/v1/session"
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["error"]["code"]).to eq("unauthenticated")

    sign_in
    get "/api/v1/session"
    expect(response.parsed_body["data"]["email"]).to eq("hr@acme.example")
  end

  it "signs out: the session is deleted and the old cookie no longer works" do
    sign_in
    token = cookies[:session_token]

    delete "/api/v1/session"
    expect(response).to have_http_status(:no_content)
    expect(Session.count).to eq(0)

    cookies[:session_token] = token
    get "/api/v1/session"
    expect(response).to have_http_status(:unauthorized)
  end

  it "expires the session after 12 hours" do
    travel_to(Time.zone.local(2026, 10, 10, 9, 0)) do
      sign_in
      travel 12.hours + 1.minute
      get "/api/v1/session"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "limits sign-in attempts to 10 per 3 minutes" do
    10.times { sign_in(password: "wrong password!!") }
    expect(response).to have_http_status(:unauthorized)

    sign_in
    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body["error"]["code"]).to eq("too_many_attempts")
  end

  it "returns 400 when email or password is missing" do
    post "/api/v1/session", params: { email: "hr@acme.example" }, as: :json

    expect(response).to have_http_status(:bad_request)
  end
end
