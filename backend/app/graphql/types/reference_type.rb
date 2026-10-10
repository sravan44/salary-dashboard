module Types
  class ReferenceType < BaseObject
    graphql_name "Reference"
    description "Values for filter dropdowns and currency choices"
    field :countries, [ CountryType ], null: false
    field :departments, [ String ], null: false
    field :currencies, [ CurrencyEnum ], null: false
    field :job_titles, [ String ], null: false

    def countries = Acme::Reference::COUNTRIES.map { |code, c| { code:, name: c[:name], currency: c[:currency] } }
    def departments = Acme::Reference.departments
    def currencies = Acme::Reference.currencies
    def job_titles = Employee.distinct.order(:job_title).pluck(:job_title)
  end
end
