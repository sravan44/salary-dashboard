module Types
  # Every field describes the same population (active employees + dashboard filters).
  class DashboardType < BaseObject
    graphql_name "Dashboard"
    MAX_LIMIT = 100
    BUCKETS = (5..20)

    field :headcount, Integer, null: false, description: "Active employees"
    field :countries_count, Integer, null: false
    field :currencies, [ CurrencyHeadcountType ], null: false, description: "Headcount per currency (never a combined amount)"
    field :headcount_by_country, [ CountryHeadcountType ], null: false
    field :headcount_by_department, [ DepartmentHeadcountType ], null: false
    field :hires_by_year, [ YearHeadcountType ], null: false, description: "Current employees by hire year, oldest first"

    # Complexity = rows requested, so asking for many large lists is rejected up front.
    field :pay_stats, [ PayStatType ], null: false, complexity: ->(_ctx, args, _child) { args[:limit] } do
      argument :group_by, PayGroupByEnum, required: true
      argument :currency, CurrencyEnum, required: false, description: "Only this currency (for single-currency charts)"
      argument :limit, Integer, required: false, default_value: Insights::PayStatsQuery::DEFAULT_LIMIT
    end

    field :distribution, [ SalaryBucketType ], null: false, complexity: 20 do
      description "Salary histogram for one currency"
      argument :currency, CurrencyEnum, required: true
      argument :buckets, Integer, required: false, default_value: 10
    end

    field :converted, ConvertedDashboardType, null: false do
      description "Indicative analytics in one reporting currency, with the rate, date and source of every conversion"
      argument :to, CurrencyEnum, required: true
    end

    def converted(to:) = { population: object, to:, snapshot: Fx::Snapshot.latest(as_of: Date.current) }

    def headcount = summary.headcount
    def countries_count = summary.countries_count
    def currencies = summary.currencies
    def headcount_by_country = summary.headcount_by_country
    def headcount_by_department = summary.headcount_by_department
    def hires_by_year = summary.hires_by_year

    def pay_stats(group_by:, limit:, currency: nil)
      raise GraphQL::ExecutionError, "limit must be between 1 and #{MAX_LIMIT}" unless limit.between?(1, MAX_LIMIT)

      Insights::PayStatsQuery.new(object, group_by:, currency:, limit:).call
    end

    def distribution(currency:, buckets:)
      raise GraphQL::ExecutionError, "buckets must be between #{BUCKETS.min} and #{BUCKETS.max}" unless BUCKETS.cover?(buckets)

      Insights::DistributionQuery.new(object, currency:, buckets:).call
    end

    private

    def summary = @summary ||= Insights::SummaryQuery.new(object).call
  end
end
