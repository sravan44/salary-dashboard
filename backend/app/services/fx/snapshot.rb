module Fx
  # The cached rates of one rate date (the latest on or before `as_of`), and the cross rates derived
  # from them: 1 `from` = rate(from, to) `to`, computed exactly from the EUR-based rates.
  class Snapshot
    STALE_AFTER_DAYS = 7
    PRECISION = 22

    attr_reader :rate_date, :source

    def self.latest(as_of: Date.current)
      date = FxRate.where(base: BASE).where(rate_date: ..as_of).maximum(:rate_date)
      return nil unless date

      rows = FxRate.where(base: BASE, rate_date: date)
      new(rate_date: date, as_of:, per_euro: rows.pluck(:quote, :rate).to_h, source: rows.pick(:source))
    end

    def initialize(rate_date:, as_of:, per_euro:, source:)
      @rate_date = rate_date
      @as_of = as_of
      @per_euro = per_euro.merge(BASE => BigDecimal(1))
      @source = source
    end

    # nil when either currency has no cached rate.
    def rate(from, to)
      return BigDecimal(1) if from == to
      return nil unless @per_euro.key?(from) && @per_euro.key?(to)

      @per_euro.fetch(to).div(@per_euro.fetch(from), PRECISION)
    end

    def stale? = (@as_of - @rate_date).to_i > STALE_AFTER_DAYS
  end
end
