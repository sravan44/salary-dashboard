require "rails_helper"

# Admins see the cached reference rates and can fetch fresh ones on demand ("Sync rates").
RSpec.describe "Exchange rates API (admin)" do
  include ActiveSupport::Testing::TimeHelpers

  around { |example| travel_to(Time.zone.local(2026, 10, 11, 9, 0)) { example.run } }

  def provider(**options) = FxHelpers::FakeProvider.new(**options)
  def use_provider(fake) = allow(Fx::FrankfurterClient).to receive(:new).and_return(fake)

  describe "GET /api/v1/exchange_rates" do
    it "lists the latest snapshot: 1 EUR in each currency, with its date, source and fetch time" do
      store_rates(Date.new(2026, 10, 2), "USD" => "1.05", "INR" => "90")
      store_rates(Date.new(2026, 10, 9), "USD" => "1.1", "INR" => "92.4", "GBP" => "0.85")
      sign_in_as(:admin)

      get "/api/v1/exchange_rates"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq(
        "base" => "EUR", "rate_date" => "2026-10-09", "source" => "ECB reference rates via Frankfurter",
        "fetched_at" => "2026-10-09T16:00:00Z", "stale" => false,
        "rates" => [
          { "currency" => "GBP", "rate" => "0.85" },
          { "currency" => "INR", "rate" => "92.4" },
          { "currency" => "USD", "rate" => "1.1" }
        ]
      )
    end

    it "flags rates more than 7 days old as stale" do
      store_rates(Date.new(2026, 10, 3), "USD" => "1.1")
      sign_in_as(:admin)

      get "/api/v1/exchange_rates"
      expect(response.parsed_body.dig("data", "stale")).to be(true)
    end

    it "says plainly when no rates have been fetched yet" do
      sign_in_as(:admin)

      get "/api/v1/exchange_rates"
      expect(response.parsed_body["data"]).to eq(
        "base" => "EUR", "rate_date" => nil, "source" => nil, "fetched_at" => nil, "stale" => false, "rates" => []
      )
    end
  end

  describe "POST /api/v1/exchange_rates/sync" do
    it "fetches fresh rates now and answers with the new snapshot" do
      store_rates(Date.new(2026, 10, 2), "USD" => "1.05")
      fake = provider(rates: { "USD" => "1.12", "INR" => "93.1" })
      use_provider(fake)
      sign_in_as(:admin)

      post "/api/v1/exchange_rates/sync", as: :json

      expect(response).to have_http_status(:ok)
      expect(fake.calls.size).to eq(1)
      data = response.parsed_body["data"]
      expect(data).to include("rate_date" => "2026-10-09", "stored" => 2, "fetched_at" => "2026-10-11T09:00:00Z", "stale" => false)
      expect(data["rates"]).to eq([ { "currency" => "INR", "rate" => "93.1" }, { "currency" => "USD", "rate" => "1.12" } ])
    end

    it "keeps the cached rates and says so when the provider can't be reached" do
      store_rates(Date.new(2026, 10, 2), "USD" => "1.05")
      use_provider(provider(error: Fx::ProviderError.new("could not reach Frankfurter (Net::OpenTimeout)")))
      sign_in_as(:admin)

      post "/api/v1/exchange_rates/sync", as: :json

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body["error"]).to include(
        "code" => "provider_unavailable",
        "message" => "Couldn't reach the rate provider, so the cached rates are unchanged. Try again later."
      )
      expect(FxRate.pluck(:rate_date, :rate)).to eq([ [ Date.new(2026, 10, 2), BigDecimal("1.05") ] ])
    end

    it "allows 5 syncs per 10 minutes, so the provider isn't hammered" do
      use_provider(provider(rates: { "USD" => "1.12" }))
      sign_in_as(:admin)

      5.times { post "/api/v1/exchange_rates/sync", as: :json }
      expect(response).to have_http_status(:ok)
      post "/api/v1/exchange_rates/sync", as: :json
      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig("error", "code")).to eq("too_many_requests")
    end

    it "is refused to everyone but Admins, without calling the provider" do
      fake = provider(rates: { "USD" => "1.12" })
      use_provider(fake)

      post "/api/v1/exchange_rates/sync", as: :json
      expect(response).to have_http_status(:unauthorized)
      %i[viewer hr_manager].each do |role|
        sign_in_as(role)
        post "/api/v1/exchange_rates/sync", as: :json
        expect(response).to have_http_status(:forbidden)
      end
      expect(fake.calls).to be_empty
    end
  end
end
