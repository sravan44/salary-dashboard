require "rails_helper"

RSpec.describe Session do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  it "hands out a random token and stores only its digest" do
    session, token = described_class.start(user, ip_address: "10.0.0.1", user_agent: "RSpec")

    expect(token.length).to be >= 40
    expect(session.token_digest).to eq(Digest::SHA256.hexdigest(token))
    expect(session.token_digest).not_to include(token)
    expect(described_class.find_active(token)).to eq(session)
  end

  it "expires 12 hours after sign-in" do
    travel_to(Time.zone.local(2026, 10, 10, 9, 0)) do
      _, token = described_class.start(user)

      travel 11.hours + 59.minutes
      expect(described_class.find_active(token)).to be_present
      travel 2.minutes
      expect(described_class.find_active(token)).to be_nil
    end
  end

  it "finds nothing for a missing or unknown token" do
    expect(described_class.find_active(nil)).to be_nil
    expect(described_class.find_active("")).to be_nil
    expect(described_class.find_active("not-a-token")).to be_nil
  end
end
