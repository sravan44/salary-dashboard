module Acme
  # Static reference data: the single validated source for countries, currencies and departments.
  # Kept in code (not tables) because nobody needs to edit it yet. See docs/domain-model.md.
  module Reference
    COUNTRIES = {
      "US" => { name: "United States",  currency: "USD" },
      "IN" => { name: "India",          currency: "INR" },
      "GB" => { name: "United Kingdom", currency: "GBP" },
      "DE" => { name: "Germany",        currency: "EUR" },
      "FR" => { name: "France",         currency: "EUR" },
      "CA" => { name: "Canada",         currency: "CAD" },
      "AU" => { name: "Australia",      currency: "AUD" },
      "SG" => { name: "Singapore",      currency: "SGD" }
    }.freeze

    DEPARTMENTS = [
      "Engineering", "Product", "Sales", "Marketing",
      "Finance", "People", "Operations", "Customer Support"
    ].freeze

    module_function

    def country_codes = COUNTRIES.keys
    def currencies = COUNTRIES.values.map { |c| c[:currency] }.uniq
    def currency_for(country_code) = COUNTRIES.dig(country_code, :currency)
    def departments = DEPARTMENTS
  end
end
