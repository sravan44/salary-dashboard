module Insights
  # Pay analytics in one reporting currency: each current salary is converted with the snapshot's
  # rate FIRST, then aggregated, so groups that span currencies get a real median. Employees whose
  # currency has no rate are left out and reported. Stored salaries are only read, never changed.
  class ConvertedQuery
    RATE_DISPLAY_DECIMALS = 10

    def initialize(population, to:, snapshot:)
      @population = population
      @to = to
      @snapshot = snapshot
    end

    def headcounts = @headcounts ||= @population.relation.group("current_comp.currency").count

    def factors
      @factors ||= headcounts.keys.filter_map do |currency|
        rate = @snapshot&.rate(currency, @to)
        [ currency, rate ] if rate
      end.to_h
    end

    # The rate used for each currency in this selection, alphabetically.
    def rates
      factors.sort.map do |currency, rate|
        { currency:, rate: rate.round(RATE_DISPLAY_DECIMALS).to_s("F"), rate_date: @snapshot.rate_date, source: @snapshot.source }
      end
    end

    def excluded
      headcounts.except(*factors.keys).sort_by { |currency, n| [ -n, currency ] }.map { |currency, n| { currency:, headcount: n } }
    end

    def included_headcount = headcounts.slice(*factors.keys).values.sum

    def pay_stats(group_by:, limit:)
      raise ArgumentError, "unknown group" unless PayStatsQuery::GROUPS.include?(group_by.to_sym)
      return [] if factors.empty?

      sql = <<~SQL.squish
        WITH #{converted_cte},
        ranked AS (
          SELECT #{group_by} AS grp, amount,
                 ROW_NUMBER() OVER (PARTITION BY #{group_by} ORDER BY amount) AS rn,
                 COUNT(*) OVER (PARTITION BY #{group_by}) AS cnt
          FROM converted
        )
        SELECT grp, MAX(cnt) AS headcount, MIN(amount) AS min, MAX(amount) AS max, AVG(amount) AS avg,
               AVG(amount) FILTER (WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)) AS median
        FROM ranked GROUP BY grp ORDER BY headcount DESC, grp ASC LIMIT #{Integer(limit)}
      SQL
      select(sql).map do |row|
        { group: row["grp"], headcount: row["headcount"], min: money(row["min"]), max: money(row["max"]),
          avg: money(row["avg"]), median: money(row["median"]) }
      end
    end

    # Equal-width histogram of converted salaries; the last bucket includes the maximum.
    def distribution(buckets:)
      return [] if factors.empty?

      # With at least one rate there is at least one converted salary, so low and high are present.
      row = select("WITH #{converted_cte} SELECT MIN(amount) AS low, MAX(amount) AS high FROM converted").first
      low, high = BigDecimal(row["low"].to_s), BigDecimal(row["high"].to_s)
      count_all = included_headcount
      return [ bucket(low, high, count_all) ] if low == high

      counts = select(ActiveRecord::Base.sanitize_sql_array([
        "WITH #{converted_cte} SELECT LEAST(WIDTH_BUCKET(amount, ?, ?, ?), ?) AS b, COUNT(*) AS n FROM converted GROUP BY b",
        low, high, buckets, buckets
      ])).to_h { |row| [ row["b"], row["n"] ] }
      width = (high - low) / buckets
      (1..buckets).map { |i| bucket(low + (width * (i - 1)), i == buckets ? high : low + (width * i), counts.fetch(i, 0)) }
    end

    private

    # Exact numeric arithmetic: the factor is a numeric literal, the product is not rounded until display.
    def converted_cte
      connection = ActiveRecord::Base.connection
      values = factors.map { |currency, rate| "(#{connection.quote(currency)}, #{connection.quote(rate.to_s('F'))}::numeric)" }.join(", ")
      <<~SQL.squish
        pop AS (#{@population.rows_sql}),
        fx (currency, factor) AS (VALUES #{values}),
        converted AS (
          SELECT pop.country, pop.department, pop.job_title, pop.amount * fx.factor AS amount
          FROM pop JOIN fx ON fx.currency = pop.currency
        )
      SQL
    end

    def select(sql) = ActiveRecord::Base.connection.select_all(sql).to_a

    def money(value) = Money.format_amount(BigDecimal(value.to_s).round(2, BigDecimal::ROUND_HALF_UP))

    def bucket(from, to, count) = { from: money(from), to: money(to), count: }
  end
end
