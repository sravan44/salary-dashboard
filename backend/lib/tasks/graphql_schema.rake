namespace :graphql do
  desc "Write the GraphQL schema (SDL) the frontend validates its queries against"
  task dump_schema: :environment do
    path = Pathname(ENV.fetch("SCHEMA_PATH") { Rails.root.join("../frontend/src/graphql/schema.graphql").to_s })
    path.write(SalaryInsightsSchema.to_definition)
    puts "Wrote #{path}"
  end
end
