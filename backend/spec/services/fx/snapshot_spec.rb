require "rails_helper"

RSpec.describe Fx::Snapshot do
  let(:today) { Date.new(2026, 10, 10) }

  it "uses the most recent cached date on or before today" do
    store_rates(Date.new(2026, 10, 2), "USD" => "1.09")
    store_rates(Date.new(2026, 10, 9), "USD" => "1.10", "INR" => "92.40")
    store_rates(Date.new(2026, 10, 12), "USD" => "9.99") # after today: ignored

    snapshot = described_class.latest(as_of: today)
    expect(snapshot.rate_date).to eq(Date.new(2026, 10, 9))
    expect(snapshot.source).to eq("ECB reference rates via Frankfurter")
  end

  it "derives cross rates exactly from the EUR-based rates" do
    store_rates(Date.new(2026, 10, 9), "USD" => "1.10", "INR" => "92.40")
    snapshot = described_class.latest(as_of: today)

    expect(snapshot.rate("INR", "USD")).to eq(BigDecimal("0.0119047619047619047619"))
    expect(snapshot.rate("EUR", "USD")).to eq(BigDecimal("1.1"))
    expect(snapshot.rate("USD", "EUR")).to eq(BigDecimal("0.9090909090909090909091"))
    expect(snapshot.rate("USD", "USD")).to eq(1)
    expect(snapshot.rate("GBP", "USD")).to be_nil # no GBP rate cached
  end

  it "is stale when the rates are more than 7 days old" do
    store_rates(Date.new(2026, 10, 3), "USD" => "1.10")
    expect(described_class.latest(as_of: today)).not_to be_stale

    expect(described_class.latest(as_of: Date.new(2026, 10, 11))).to be_stale
  end

  it "is nil when nothing has been fetched yet" do
    expect(described_class.latest(as_of: today)).to be_nil
  end
end
