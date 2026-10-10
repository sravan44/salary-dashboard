module Types
  class QueryType < BaseObject
    graphql_name "Query"

    field :dashboard, DashboardType, null: false, description: "Pay insights for active employees" do
      argument :filters, DashboardFiltersInput, required: false
    end
    field :reference, ReferenceType, null: false

    def dashboard(filters: nil) = Insights::Population.new(filters&.to_h || {})
    def reference = :reference
  end
end
