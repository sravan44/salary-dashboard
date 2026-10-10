# GraphQL schema for the pay dashboard. Limits protect the database from expensive queries.
class SalaryInsightsSchema < GraphQL::Schema
  query Types::QueryType

  max_depth 8
  max_complexity 200
  validate_max_errors 20
  use GraphQL::Schema::Timeout, max_seconds: 5
end
