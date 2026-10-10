# Same schema with schema browsing (introspection) switched off. Used when GraphiQL is disabled,
# which is the default for real deployments (see GraphqlController).
class SalaryInsightsSchemaWithoutIntrospection < SalaryInsightsSchema
  disable_introspection_entry_points
end
