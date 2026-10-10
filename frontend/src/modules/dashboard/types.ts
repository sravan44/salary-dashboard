export type CurrencyHeadcount = { currency: string; headcount: number }
export type CountryHeadcount = { countryCode: string; countryName: string; headcount: number }
export type DepartmentHeadcount = { department: string; headcount: number }
export type YearHeadcount = { year: number; headcount: number }
export type SalaryBucket = { from: string; to: string; count: number }
export type PayStat = { group: string; currency: string; headcount: number; min: string; max: string; avg: string; median: string }

export type DashboardReference = {
  countries: { code: string; name: string; currency: string }[]
  departments: string[]
  currencies: string[]
  jobTitles: string[]
}

export type OverviewData = {
  dashboard: {
    headcount: number
    countriesCount: number
    currencies: CurrencyHeadcount[]
    headcountByCountry: CountryHeadcount[]
    headcountByDepartment: DepartmentHeadcount[]
    hiresByYear: YearHeadcount[]
  }
  reference: DashboardReference
}

export type CurrencyDetailData = { dashboard: { distribution: SalaryBucket[]; byDepartment: PayStat[]; byJobTitle: PayStat[] } }

/** GraphQL DashboardFilters: department uses the schema's enum name (e.g. CUSTOMER_SUPPORT). */
export type DashboardFiltersInput = { country?: string; department?: string; jobTitle?: string }
