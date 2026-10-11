require "rails_helper"

RSpec.describe Fx::Refresh do
  include ActiveSupport::Testing::TimeHelpers

  around { |example| travel_to(Time.zone.local(2026, 10, 10, 6, 0)) { example.run } }

  let(:provider) { FxHelpers::FakeProvider.new(rates: { "USD" => "1.10", "INR" => "92.40", "GBP" => "0.85", "CAD" => "1.51", "AUD" => "1.66", "SGD" => "1.43" }) }

  it "asks the provider once for all supported currencies against EUR, and stores each rate with its date and source" do
    result = described_class.call(client: provider)

    expect(provider.calls).to eq([ { base: "EUR", symbols: %w[USD INR GBP CAD AUD SGD] } ])
    expect(result).to eq(date: Date.new(2026, 10, 9), stored: 6)
    expect(FxRate.find_by!(quote: "INR")).to have_attributes(
      base: "EUR", rate: BigDecimal("92.40"), rate_date: Date.new(2026, 10, 9),
      source: "ECB reference rates via Frankfurter", fetched_at: Time.zone.local(2026, 10, 10, 6, 0)
    )
  end

  it "is safe to run again for the same date (no duplicates; the latest fetch wins)" do
    described_class.call(client: provider)
    described_class.call(client: FxHelpers::FakeProvider.new(rates: { "USD" => "1.11" }))

    expect(FxRate.where(quote: "USD").pluck(:rate)).to eq([ BigDecimal("1.11") ])
    expect(FxRate.count).to eq(6)
  end

  it "keeps the previous snapshot when the provider fails, and reports the failure" do
    store_rates(Date.new(2026, 10, 2), "USD" => "1.09")

    expect { described_class.call(client: FxHelpers::FakeProvider.new(error: Fx::ProviderError.new("timeout"))) }
      .to raise_error(Fx::ProviderError, "timeout")
    expect(FxRate.pluck(:rate_date, :rate)).to eq([ [ Date.new(2026, 10, 2), BigDecimal("1.09") ] ])
  end

  it "stores nothing (and says so) when the provider returns no usable rates" do
    expect(described_class.call(client: FxHelpers::FakeProvider.new(rates: { "JPY" => "160" }))).to eq(date: Date.new(2026, 10, 9), stored: 0)
    expect(FxRate.count).to eq(0)
  end

  it "ignores currencies we do not support and non-positive rates" do
    result = described_class.call(client: FxHelpers::FakeProvider.new(rates: { "USD" => "1.10", "JPY" => "160", "INR" => "0" }))

    expect(result[:stored]).to eq(1)
    expect(FxRate.pluck(:quote)).to eq([ "USD" ])
  end
end
