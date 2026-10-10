module Insights
  # Min / max / average / median salary per group, always per (group, currency): amounts in
  # different currencies are never combined. Definitions: docs/analytics-definitions.md.
  class PayStatsQuery
    GROUPS = %i[country department job_title].freeze
    DEFAULT_LIMIT = 50

    def initialize(population, group_by:, currency: nil, limit: DEFAULT_LIMIT)
      raise ArgumentError, "group_by must be one of #{GROUPS.join(', ')}" unless GROUPS.include?(group_by.to_sym)

      @population = population
      @group = group_by.to_sym
      @currency = currency
      @limit = limit
    end

    def call
      ActiveRecord::Base.connection.select_all(sql).map do |row|
        {
          group: row["grp"], currency: row["currency"], headcount: row["headcount"],
          min: money(row["min"]), max: money(row["max"]), avg: money(row["avg"]), median: money(row["median"])
        }
      end
    end

    private

    # The median is exact: the middle row (odd count) or the mean of the two middle rows (even
    # count), in numeric arithmetic. Postgres' percentile_cont would go through floating point.
    def sql
      ActiveRecord::Base.sanitize_sql_array([ <<~SQL.squish, { currency: @currency, limit: @limit } ])
        WITH pop AS (#{@population.rows_sql}),
        ranked AS (
          SELECT #{@group} AS grp, currency, amount,
                 ROW_NUMBER() OVER (PARTITION BY #{@group}, currency ORDER BY amount) AS rn,
                 COUNT(*) OVER (PARTITION BY #{@group}, currency) AS cnt
          FROM pop
          WHERE (:currency)::text IS NULL OR currency = :currency
        )
        SELECT grp, currency, MAX(cnt) AS headcount, MIN(amount) AS min, MAX(amount) AS max,
               ROUND(AVG(amount), 2) AS avg,
               ROUND(AVG(amount) FILTER (WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)), 2) AS median
        FROM ranked
        GROUP BY grp, currency
        ORDER BY headcount DESC, grp ASC, currency ASC
        LIMIT :limit
      SQL
    end

    def money(value) = Money.format_amount(BigDecimal(value.to_s))
  end
end
