# POST /graphql: { query, variables, operationName } → { data, errors }.
class GraphqlController < ApplicationController
  def execute
    result = schema.execute(
      params[:query],
      variables: params[:variables].respond_to?(:to_unsafe_h) ? params[:variables].to_unsafe_h : {},
      operation_name: params[:operationName]
    )
    render json: result
  end

  def method_not_allowed
    response.headers["Allow"] = "POST"
    head :method_not_allowed
  end

  private

  # Schema browsing is on only where GraphiQL is enabled (local/dev by default).
  def schema
    Rails.configuration.x.graphiql_enabled ? SalaryInsightsSchema : SalaryInsightsSchemaWithoutIntrospection
  end
end
