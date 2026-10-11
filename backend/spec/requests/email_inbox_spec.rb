require "rails_helper"

# The demo email inbox (letter_opener_web at /letter_opener): Admins only, and only where EMAIL_INBOX is on
# (development and test by default; the demo server opts in). Anyone else never reaches it: a page request
# falls through to the React app, and its actions don't exist for them.
RSpec.describe "Demo email inbox" do
  def inbox_shown? = response.body.include?("<title>LetterOpenerWeb</title>")

  it "opens for an Admin" do
    sign_in_as(:admin)
    get "/letter_opener"

    expect(response).to have_http_status(:ok)
    expect(inbox_shown?).to be(true)
  end

  it "lets an Admin clear it" do
    sign_in_as(:admin)
    post "/letter_opener/clear"

    expect(response).to redirect_to("/letter_opener/")
  end

  [ [ :viewer ], [ :hr_manager ], [] ].each do |roles|
    who = roles.empty? ? "someone signed out" : "a #{roles.first.to_s.tr('_', ' ')}"

    it "is hidden from #{who}" do
      sign_in_as(*roles) if roles.any?

      get "/letter_opener"
      expect(inbox_shown?).to be(false)
      post "/letter_opener/clear"
      expect(response).to have_http_status(:not_found)
    end
  end

  it "is hidden even from an Admin when the inbox is switched off" do
    sign_in_as(:admin)
    allow(Rails.configuration.x).to receive(:email_inbox).and_return(false)

    get "/letter_opener"
    expect(inbox_shown?).to be(false)
  end

  it "refuses an expired session" do
    sign_in_as(:admin)
    Session.update_all(expires_at: 1.minute.ago)

    get "/letter_opener"
    expect(inbox_shown?).to be(false)
  end

  describe "the session tells the app whether to show the inbox link" do
    it "is true for an Admin while the inbox is on" do
      sign_in_as(:admin)
      expect(response.parsed_body.dig("data", "email_inbox")).to be(true)
    end

    it "is false for anyone else" do
      sign_in_as(:hr_manager)
      expect(response.parsed_body.dig("data", "email_inbox")).to be(false)
    end

    it "is false for an Admin when the inbox is off" do
      allow(Rails.configuration.x).to receive(:email_inbox).and_return(false)
      sign_in_as(:admin)
      expect(response.parsed_body.dig("data", "email_inbox")).to be(false)
    end
  end
end
