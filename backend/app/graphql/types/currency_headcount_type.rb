module Types
  class CurrencyHeadcountType < BaseObject
    graphql_name "CurrencyHeadcount"
    field :currency, CurrencyEnum, null: false
    field :headcount, Integer, null: false
  end
end
