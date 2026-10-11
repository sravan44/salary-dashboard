require "rails_helper"

# Signed in: change my own password.
RSpec.describe "Change my password API" do
  let!(:user) { sign_in_as(:viewer, email: "viewer@acme.example") }

  def change(current:, password: "a brand new password", confirmation: password)
    patch "/api/v1/password", params: { current_password: current, password:, password_confirmation: confirmation }, as: :json
  end

  it "changes the password, keeps this session, and signs out the others" do
    other, = Session.start(user)

    change(current: AuthHelpers::PASSWORD)

    expect(response).to have_http_status(:no_content)
    expect(user.reload.authenticate("a brand new password")).to eq(user)
    expect(Session.exists?(other.id)).to be(false)
    get "/api/v1/session"
    expect(response).to have_http_status(:ok)
  end

  it "requires the current password" do
    change(current: "not my password")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]["details"]).to eq("current_password" => [ "is incorrect" ])
    expect(user.reload.authenticate(AuthHelpers::PASSWORD)).to eq(user)
  end

  it "rejects a short new password" do
    change(current: AuthHelpers::PASSWORD, password: "short")

    expect(response.parsed_body["error"]["details"]).to eq("password" => [ "is too short (minimum is 12 characters)" ])
  end

  it "rejects a confirmation that doesn't match" do
    change(current: AuthHelpers::PASSWORD, confirmation: "something else entirely")

    expect(response.parsed_body["error"]["details"]).to eq("password_confirmation" => [ "doesn't match Password" ])
  end

  it "needs a signed-in user" do
    delete "/api/v1/session"
    change(current: AuthHelpers::PASSWORD)

    expect(response).to have_http_status(:unauthorized)
  end
end
