require "rails_helper"

RSpec.describe Fx::Conversion do
  before { store_rates(Date.new(2026, 10, 9), "USD" => "1.10", "INR" => "92.40") }

  let(:snapshot) { Fx::Snapshot.latest(as_of: Date.new(2026, 10, 10)) }

  it "converts an amount exactly, rounded to 2 dp half up" do
    usd = described_class.new(to: "USD", snapshot:)

    expect(usd.convert(BigDecimal("1800000"), "INR")).to eq(BigDecimal("21428.57"))
    expect(usd.convert(BigDecimal("2000000"), "INR")).to eq(BigDecimal("23809.52"))
    expect(usd.convert(BigDecimal("98000"), "USD")).to eq(BigDecimal("98000"))
  end

  it "returns nil when a currency has no rate, or when there are no rates at all" do
    expect(described_class.new(to: "GBP", snapshot:).convert(BigDecimal("1"), "INR")).to be_nil
    expect(described_class.new(to: "USD", snapshot: nil).convert(BigDecimal("1"), "USD")).to be_nil
  end

  it "describes the rates it used for the given currencies (provenance), and the missing ones" do
    expect(described_class.new(to: "USD", snapshot:).details(%w[USD INR SGD])).to eq(
      to: "USD", available: true, rate_date: "2026-10-09", source: "ECB reference rates via Frankfurter", stale: false,
      rates: [ { currency: "INR", rate: "0.0119047619" }, { currency: "USD", rate: "1.0" } ], missing: [ "SGD" ]
    )
  end

  it "says when nothing can be converted because no rates have been fetched" do
    expect(described_class.new(to: "USD", snapshot: nil).details(%w[INR])).to eq(
      to: "USD", available: false, rate_date: nil, source: nil, stale: false, rates: [], missing: [ "INR" ]
    )
  end
end
