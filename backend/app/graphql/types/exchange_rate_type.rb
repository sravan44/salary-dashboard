module Types
  class ExchangeRateType < BaseObject
    graphql_name "ExchangeRate"
    description "The rate used to convert one currency: 1 `currency` = `rate` of the reporting currency"
    field :currency, CurrencyEnum, null: false
    field :rate, String, null: false, description: "Exact decimal string (10 dp)"
    field :rate_date, GraphQL::Types::ISO8601Date, null: false, description: "The date the reference rate was published for"
    field :source, String, null: false
  end
end
