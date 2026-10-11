module Fx
  # Converts single amounts into a reporting currency at the latest cached reference rates, and
  # describes the rates it used (provenance). Indicative only: stored salaries are never changed.
  class Conversion
    attr_reader :to

    def initialize(to:, snapshot: Snapshot.latest)
      @to = to
      @snapshot = snapshot
    end

    # Exact decimal arithmetic, rounded to 2 dp half up; nil when there is no rate.
    def convert(amount, currency)
      rate = @snapshot&.rate(currency, @to)
      rate && (amount * rate).round(2, BigDecimal::ROUND_HALF_UP)
    end

    # Provenance for the currencies on screen: which rates (rate date, source), and which are missing.
    def details(currencies)
      with_rate, missing = currencies.uniq.sort.partition { |currency| @snapshot&.rate(currency, @to) }
      {
        to: @to, available: !@snapshot.nil?, rate_date: @snapshot&.rate_date&.iso8601, source: @snapshot&.source,
        stale: @snapshot&.stale? || false,
        rates: with_rate.map { |currency| { currency:, rate: Fx.display_rate(@snapshot.rate(currency, @to)) } },
        missing:
      }
    end
  end
end
