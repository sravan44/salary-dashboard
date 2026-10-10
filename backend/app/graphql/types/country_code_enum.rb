module Types
  class CountryCodeEnum < BaseEnum
    graphql_name "CountryCode"
    description "Supported country (ISO-3166 alpha-2)"
    Acme::Reference::COUNTRIES.each { |code, country| value code, country[:name], value: code }
  end
end
