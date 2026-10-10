module Types
  class PayStatType < BaseObject
    graphql_name "PayStat"
    description "Salary statistics for one group in ONE currency. Amounts are exact decimal strings."
    field :group, String, null: false
    field :currency, CurrencyEnum, null: false
    field :headcount, Integer, null: false
    field :min, String, null: false
    field :max, String, null: false
    field :avg, String, null: false, description: "Mean, rounded to 2 decimals (half up)"
    field :median, String, null: false, description: "Exact median; mean of the two middle values for an even count"
  end
end
