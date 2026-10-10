module Types
  class DashboardFiltersInput < BaseInputObject
    graphql_name "DashboardFilters"
    description "Narrow every dashboard widget to the same employees (active employees only)"
    MAX_VALUES = 50

    # Lists: several values are OR-ed; a single value (country: DE) is still accepted.
    argument :country, [ CountryCodeEnum ], required: false, validates: { length: { maximum: MAX_VALUES } }
    argument :department, [ DepartmentEnum ], required: false, validates: { length: { maximum: MAX_VALUES } }
    argument :job_title, [ String ], required: false, validates: { length: { maximum: MAX_VALUES } }
  end
end
