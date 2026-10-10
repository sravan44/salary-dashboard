module Types
  class CurrencyEnum < BaseEnum
    graphql_name "Currency"
    description "Supported currency (ISO-4217)"
    Acme::Reference.currencies.each { |code| value code, value: code }
  end
end
