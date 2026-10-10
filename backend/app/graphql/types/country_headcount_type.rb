module Types
  class CountryHeadcountType < BaseObject
    graphql_name "CountryHeadcount"
    field :country_code, CountryCodeEnum, null: false
    field :country_name, String, null: false
    field :headcount, Integer, null: false

    def country_name = Acme::Reference::COUNTRIES.dig(object[:country_code], :name)
  end
end
