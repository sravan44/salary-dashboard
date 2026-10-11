# A cached rate snapshot for specs (EUR base, as the ECB publishes them). Never from the network.
module FxHelpers
  def store_rates(date, source: Fx::SOURCE, **rates)
    rates.each do |quote, rate|
      FxRate.create!(base: "EUR", quote:, rate_date: date, rate:, source:, fetched_at: Time.zone.parse("#{date} 16:00"))
    end
  end

  # A stand-in for Fx::FrankfurterClient.
  class FakeProvider
    attr_reader :calls

    def initialize(date: Date.new(2026, 10, 9), rates: {}, error: nil)
      @date, @rates, @error, @calls = date, rates, error, []
    end

    def latest(base:, symbols:)
      @calls << { base:, symbols: }
      raise @error if @error

      { date: @date, rates: @rates.transform_values { |rate| BigDecimal(rate.to_s) } }
    end
  end
end

RSpec.configure do |config|
  config.include FxHelpers
  # The in-memory rate copy belongs to the process; every example starts without one.
  config.before { Fx::Snapshot.clear_memory! }
end
