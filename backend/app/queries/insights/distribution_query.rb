module Insights
  # Salary histogram for ONE currency: the range min..max split into equal-width buckets.
  # The last bucket includes the maximum, so bucket counts always add up to the headcount.
  class DistributionQuery
    def initialize(population, currency:, buckets:)
      @population = population
      @currency = currency
      @buckets = buckets
    end

    def call
      scope = @population.relation.where(current_comp: { currency: @currency })
      low, high = scope.pick(Arel.sql("MIN(current_comp.amount)"), Arel.sql("MAX(current_comp.amount)"))
      return [] if low.nil?
      return [ bucket(low, high, scope.count) ] if low == high

      counts = scope.group(Arel.sql(bucket_sql(low, high))).count
      width = (high - low) / @buckets
      (1..@buckets).map do |i|
        bucket(low + (width * (i - 1)), i == @buckets ? high : low + (width * i), counts.fetch(i, 0))
      end
    end

    private

    def bucket_sql(low, high)
      ActiveRecord::Base.sanitize_sql_array(
        [ "LEAST(WIDTH_BUCKET(current_comp.amount, ?, ?, ?), ?)", low, high, @buckets, @buckets ]
      )
    end

    def bucket(from, to, count) = { from: Money.format_amount(from), to: Money.format_amount(to), count: count }
  end
end
