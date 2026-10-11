module Fx
  # The cached rates of one rate date (the latest on or before `as_of`), and the cross rates derived
  # from them: 1 `from` = rate(from, to) `to`, computed exactly from the EUR-based rates.
  class Snapshot
    STALE_AFTER_DAYS = 7
    PRECISION = 22

    attr_reader :rate_date, :source

    MEMORY_LOCK = Mutex.new

    # Each request runs one cheap query (latest rate date and fetch time). The rates themselves are
    # kept in memory and re-read only when that version changes, e.g. after the scheduled refresh,
    # which runs in another process and so cannot clear this copy directly.
    def self.latest(as_of: Date.current)
      date, fetched_at = FxRate.where(base: BASE, rate_date: ..as_of).pick(Arel.sql("MAX(rate_date)"), Arel.sql("MAX(fetched_at)"))
      return nil unless date

      data = remembered([ date, fetched_at ]) do
        rows = FxRate.where(base: BASE, rate_date: date).pluck(:quote, :rate, :source)
        { per_euro: rows.to_h { |quote, rate, _| [ quote, rate ] }, source: rows.first.last } # a date always has rows
      end
      new(rate_date: date, as_of:, **data)
    end

    def self.clear_memory! = MEMORY_LOCK.synchronize { @memory = nil }

    def self.remembered(version)
      MEMORY_LOCK.synchronize do
        @memory = { version:, data: yield } unless @memory && @memory[:version] == version
        @memory[:data]
      end
    end
    private_class_method :remembered

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
