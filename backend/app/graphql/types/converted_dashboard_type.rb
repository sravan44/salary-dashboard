module Types
  # Indicative analytics in one reporting currency, always with the provenance of every rate used.
  class ConvertedDashboardType < BaseObject
    graphql_name "ConvertedDashboard"
    description "Analytics converted into a reporting currency at cached reference rates. Stored salaries are never changed."

    field :reporting_currency, CurrencyEnum, null: false
    field :available, Boolean, null: false, description: "False when no rates have been fetched yet"
    field :rate_date, GraphQL::Types::ISO8601Date, null: true
    field :source, String, null: true
    field :stale, Boolean, null: false, description: "True when the rates are more than 7 days old"
    field :rates, [ ExchangeRateType ], null: false, description: "One per currency in the selection that could be converted"
    field :excluded_currencies, [ CurrencyHeadcountType ], null: false, description: "Employees left out: no rate for their currency"
    field :included_headcount, Integer, null: false

    field :pay_stats, [ ConvertedPayStatType ], null: false, complexity: ->(_ctx, args, _child) { args[:limit] } do
      argument :group_by, PayGroupByEnum, required: true
      argument :limit, Integer, required: false, default_value: Insights::PayStatsQuery::DEFAULT_LIMIT
    end

    field :distribution, [ SalaryBucketType ], null: false, complexity: 20 do
      argument :buckets, Integer, required: false, default_value: 10
    end

    def reporting_currency = object[:to]
    def available = !snapshot.nil?
    def rate_date = snapshot&.rate_date
    def source = snapshot&.source
    def stale = snapshot&.stale? || false
    def rates = query.rates
    def excluded_currencies = query.excluded
    def included_headcount = query.included_headcount

    def pay_stats(group_by:, limit:)
      raise GraphQL::ExecutionError, "limit must be between 1 and #{DashboardType::MAX_LIMIT}" unless limit.between?(1, DashboardType::MAX_LIMIT)

      query.pay_stats(group_by:, limit:)
    end

    def distribution(buckets:)
      range = DashboardType::BUCKETS
      raise GraphQL::ExecutionError, "buckets must be between #{range.min} and #{range.max}" unless range.cover?(buckets)

      query.distribution(buckets:)
    end

    private

    def snapshot = object[:snapshot]
    def query = @query ||= Insights::ConvertedQuery.new(object[:population], to: object[:to], snapshot:)
  end
end
