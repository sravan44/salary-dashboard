require "rails_helper"

RSpec.describe FxRefreshJob do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  around { |example| travel_to(Time.zone.local(2026, 10, 9, 14, 30)) { example.run } } # 16:30 in Frankfurt

  def provider(**options) = FxHelpers::FakeProvider.new(rates: { "USD" => "1.10", "INR" => "92.40" }, **options)

  it "refreshes the cached rates" do
    allow(Fx::FrankfurterClient).to receive(:new).and_return(provider)

    described_class.perform_now

    expect(FxRate.order(:quote).pluck(:quote, :rate_date)).to eq([ [ "INR", Date.new(2026, 10, 9) ], [ "USD", Date.new(2026, 10, 9) ] ])
  end

  it "retries a provider failure 30 minutes later, and keeps the cached rates meanwhile" do
    store_rates(Date.new(2026, 10, 8), "USD" => "1.09")
    allow(Fx::FrankfurterClient).to receive(:new).and_return(provider(error: Fx::ProviderError.new("could not reach Frankfurter")))

    described_class.perform_now

    expect(described_class).to have_been_enqueued.at(30.minutes.from_now)
    expect(FxRate.pluck(:rate_date, :rate)).to eq([ [ Date.new(2026, 10, 8), BigDecimal("1.09") ] ])
  end

  it "gives up after 3 attempts, logs why, and leaves the cache as it was (the dashboard then shows rates as stale)" do
    allow(Fx::FrankfurterClient).to receive(:new).and_return(provider(error: Fx::ProviderError.new("could not reach Frankfurter")))
    allow(Rails.logger).to receive(:error)

    perform_enqueued_jobs { described_class.perform_later }

    expect(Fx::FrankfurterClient).to have_received(:new).exactly(3).times
    expect(Rails.logger).to have_received(:error).with("FX refresh gave up after 3 attempts: could not reach Frankfurter. Cached rates are unchanged.")
    expect(enqueued_jobs).to be_empty
    expect(FxRate.count).to eq(0)
  end
end
