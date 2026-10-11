require "rails_helper"

# Hand-calculated from spec/support/insights_fixture.rb with 1 EUR = 1.10 USD = 92.40 INR:
#   USD 120,000 · 100,000 · 90,000 (as is)   INR 2,400,000 → 28,571.43 USD   EUR 72,000 → 79,200 · 65,000 → 71,500
RSpec.describe Insights::ConvertedQuery do
  before do
    create_insights_fixture
    store_rates(Date.new(2026, 10, 9), "USD" => "1.10", "INR" => "92.40")
  end

  let(:snapshot) { Fx::Snapshot.latest(as_of: Date.new(2026, 10, 10)) }
  let(:everyone) { Insights::Population.new }

  def query(population: everyone, to: "USD") = described_class.new(population, to:, snapshot:)

  it "converts each salary first, then aggregates across currencies (exact median, average half up)" do
    expect(query.pay_stats(group_by: :department, limit: 50)).to eq([
      { group: "Engineering", headcount: 3, min: "28571.43", max: "120000.00", avg: "82857.14", median: "100000.00" },
      { group: "People", headcount: 2, min: "71500.00", max: "79200.00", avg: "75350.00", median: "75350.00" },
      { group: "Sales", headcount: 1, min: "90000.00", max: "90000.00", avg: "90000.00", median: "90000.00" }
    ])
  end

  it "builds the histogram from converted salaries; counts add up to the converted headcount" do
    buckets = query.distribution(buckets: 5)

    expect(buckets.map { |b| b[:count] }).to eq([ 1, 0, 2, 2, 1 ])
    expect(buckets.first[:from]).to eq("28571.43")
    expect(buckets.last[:to]).to eq("120000.00")
  end

  it "lists the rate used for each currency in the selection, with date and source" do
    expect(query.rates).to eq([
      { currency: "EUR", rate: "1.1", rate_date: Date.new(2026, 10, 9), source: "ECB reference rates via Frankfurter" },
      { currency: "INR", rate: "0.0119047619", rate_date: Date.new(2026, 10, 9), source: "ECB reference rates via Frankfurter" },
      { currency: "USD", rate: "1.0", rate_date: Date.new(2026, 10, 9), source: "ECB reference rates via Frankfurter" }
    ])
  end

  it "leaves out, and reports, employees whose currency has no rate" do
    FxRate.where(quote: "INR").delete_all
    converted = described_class.new(everyone, to: "USD", snapshot: Fx::Snapshot.latest(as_of: Date.new(2026, 10, 10)))

    expect(converted.excluded).to eq([ { currency: "INR", headcount: 1 } ])
    expect(converted.included_headcount).to eq(5)
    expect(converted.pay_stats(group_by: :department, limit: 50).first).to include(group: "Engineering", headcount: 2)
  end

  # In EUR: US 120,000 / 100,000 / 90,000 USD ÷ 1.10 → median 90,909.09; IN 2,400,000 ÷ 92.40 = 25,974.03
  it "converts into EUR as well (the ECB base)" do
    stats = query(to: "EUR").pay_stats(group_by: :country, limit: 50).to_h { |row| [ row[:group], row[:median] ] }

    expect(stats).to eq("US" => "90909.09", "IN" => "25974.03", "DE" => "72000.00", "FR" => "65000.00")
  end

  it "applies the dashboard filters" do
    people = query(population: Insights::Population.new(department: %w[People]))

    expect(people.pay_stats(group_by: :country, limit: 50).map { |r| [ r[:group], r[:median] ] })
      .to eq([ [ "DE", "79200.00" ], [ "FR", "71500.00" ] ])
  end

  it "gives a single bucket when everyone earns the same converted amount" do
    one = described_class.new(Insights::Population.new(department: %w[Sales]), to: "USD", snapshot:)

    expect(one.distribution(buckets: 5)).to eq([ { from: "90000.00", to: "90000.00", count: 1 } ])
  end

  it "refuses an unknown grouping" do
    expect { query.pay_stats(group_by: :salary, limit: 5) }.to raise_error(ArgumentError)
  end

  it "never changes stored salaries" do
    expect { query.pay_stats(group_by: :department, limit: 50) }.not_to(change { Compensation.pluck(:amount, :currency).sort })
  end

  it "returns nothing to convert without a snapshot" do
    converted = described_class.new(everyone, to: "USD", snapshot: nil)

    expect(converted.pay_stats(group_by: :department, limit: 50)).to eq([])
    expect(converted.distribution(buckets: 5)).to eq([])
    expect(converted.excluded).to eq([ { currency: "USD", headcount: 3 }, { currency: "EUR", headcount: 2 }, { currency: "INR", headcount: 1 } ])
  end
end
