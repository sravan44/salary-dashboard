require "rails_helper"

# Signed out: "Forgot password?" sends a link; the link (reset or first set-password) sets a new password.
RSpec.describe "Password reset API" do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) { create(:user, email: "hr@acme.example", password: "correct horse battery") }

  def ask(email) = post("/api/v1/password_reset", params: { email: }, as: :json)

  def reset(token, password = "a brand new password", confirmation = password)
    patch "/api/v1/password_reset", params: { token:, password:, password_confirmation: confirmation }, as: :json
  end

  describe "asking for a link" do
    it "emails a reset link to a known address" do
      expect { ask(" HR@acme.example ") }.to have_enqueued_mail(UserMailer, :password_reset).with(user)

      expect(response).to have_http_status(:accepted)
    end

    it "answers exactly the same for an unknown address, and sends nothing" do
      ask("hr@acme.example")
      known = response.parsed_body

      expect { ask("nobody@acme.example") }.not_to have_enqueued_mail
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to eq(known)
    end

    it "limits requests to 5 per 15 minutes per address of origin" do
      5.times { ask("hr@acme.example") }
      ask("hr@acme.example")

      expect(response).to have_http_status(:too_many_requests)
    end

    it "needs an email" do
      post "/api/v1/password_reset", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "using a link" do
    it "sets the new password, signs out every session, and the link then stops working" do
      post "/api/v1/session", params: { email: "hr@acme.example", password: "correct horse battery" }, as: :json
      token = user.password_reset_token

      reset(token)

      expect(response).to have_http_status(:no_content)
      expect(user.reload.authenticate("a brand new password")).to eq(user)
      expect(user.sessions).to be_empty
      expect(Version.where(item: user, event: "update").last.whodunnit).to eq("hr@acme.example (link)")

      reset(token, "yet another password")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["code"]).to eq("invalid_token")
    end

    it "accepts a set-password link from an invitation" do
      reset(user.generate_token_for(:password_setup))

      expect(response).to have_http_status(:no_content)
      expect(user.reload.password_set?).to be(true)
    end

    it "refuses an expired link" do
      token = user.password_reset_token

      travel 3.hours do
        reset(token)
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("code" => "invalid_token", "message" => "This link is invalid or has expired. Ask for a new one.")
    end

    it "limits link attempts to 10 per 15 minutes, so tokens can't be guessed at speed" do
      10.times { reset("guess") }
      reset(user.password_reset_token)

      expect(response).to have_http_status(:too_many_requests)
      expect(user.reload.authenticate("correct horse battery")).to eq(user)
    end

    it "counts link attempts separately from link requests" do
      5.times { reset("guess") }
      ask("hr@acme.example")

      expect(response).to have_http_status(:accepted)
    end

    it "refuses a made-up link" do
      reset("not-a-real-token")

      expect(response.parsed_body["error"]["code"]).to eq("invalid_token")
    end

    it "keeps the link usable when the new password is rejected" do
      token = user.password_reset_token

      reset(token, "short")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["details"]).to eq("password" => [ "is too short (minimum is 12 characters)" ])

      reset(token, "a brand new password", "a different one")
      expect(response.parsed_body["error"]["details"]).to eq("password_confirmation" => [ "doesn't match Password" ])

      reset(token)
      expect(response).to have_http_status(:no_content)
    end
  end
end
