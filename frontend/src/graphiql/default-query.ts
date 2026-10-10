/** The query GraphiQL opens with: the whole dashboard for one set of filters. */
export const DEFAULT_QUERY = `# ACME Salary Insights: pay dashboard over GraphQL.
# Salary figures are always per currency. Limits: depth 8, complexity 200, limit <= 100, 5-20 buckets.
query Dashboard($filters: DashboardFilters) {
  dashboard(filters: $filters) {
    headcount
    countriesCount
    currencies { currency headcount }
    headcountByCountry { countryCode countryName headcount }
    byDepartment: payStats(groupBy: DEPARTMENT, currency: USD, limit: 10) {
      group currency headcount min max avg median
    }
    distribution(currency: USD, buckets: 10) { from to count }
  }
}
`

export const DEFAULT_VARIABLES = JSON.stringify({ filters: { country: 'US' } }, null, 2)
