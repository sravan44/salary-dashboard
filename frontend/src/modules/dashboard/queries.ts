/** Everything that does not depend on a currency: tiles, headcount by country, filter choices. */
export const DASHBOARD_OVERVIEW = `
  query DashboardOverview($filters: DashboardFilters) {
    dashboard(filters: $filters) {
      headcount
      countriesCount
      currencies { currency headcount }
      headcountByCountry { countryCode countryName headcount }
      headcountByDepartment { department headcount }
      hiresByYear { year headcount }
    }
    reference { countries { code name currency } departments currencies jobTitles }
  }
`

/** Salary charts for ONE currency, so amounts are never mixed. */
export const DASHBOARD_CURRENCY_DETAIL = `
  query DashboardCurrencyDetail($filters: DashboardFilters, $currency: Currency!) {
    dashboard(filters: $filters) {
      distribution(currency: $currency, buckets: 10) { from to count }
      byDepartment: payStats(groupBy: DEPARTMENT, currency: $currency, limit: 20) {
        group currency headcount min max avg median
      }
      byJobTitle: payStats(groupBy: JOB_TITLE, currency: $currency, limit: 10) {
        group currency headcount min max avg median
      }
    }
  }
`
