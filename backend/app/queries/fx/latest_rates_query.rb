module Fx
  # The latest cached snapshot as the Admin's Exchange rates page shows it: 1 EUR in each currency,
  # with the rate date, source and fetch time. Empty (all nil) until rates have been fetched once.
  class LatestRatesQuery
    def self.call(as_of: Date.current)
      date = FxRate.where(base: BASE, rate_date: ..as_of).maximum(:rate_date)
      rows = date ? FxRate.where(base: BASE, rate_date: date).order(:quote).to_a : []

      {
        base: BASE,
        rate_date: date&.iso8601,
        source: rows.first&.source,
        fetched_at: rows.map(&:fetched_at).max&.utc&.iso8601,
        stale: date.present? && (as_of - date).to_i > Snapshot::STALE_AFTER_DAYS,
        rates: rows.map { |row| { currency: row.quote, rate: Fx.display_rate(row.rate) } }
      }
    end
  end
end
