module Types
  class CountryType < BaseObject
    graphql_name "Country"
    field :code, CountryCodeEnum, null: false
    field :name, String, null: false
    field :currency, CurrencyEnum, null: false
  end
end
