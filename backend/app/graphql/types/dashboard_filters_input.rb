module Types
  class DashboardFiltersInput < BaseInputObject
    graphql_name "DashboardFilters"
    description "Narrow every dashboard widget to the same employees (active employees only)"
    argument :country, CountryCodeEnum, required: false
    argument :department, DepartmentEnum, required: false
    argument :job_title, String, required: false
  end
end
