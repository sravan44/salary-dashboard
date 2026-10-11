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

/** GraphQL DashboardFilters: lists (OR within a filter); department uses the enum name (e.g. CUSTOMER_SUPPORT). */
export type DashboardFiltersInput = { country?: string[]; department?: string[]; jobTitle?: string[] }

export type ExchangeRate = { currency: string; rate: string; rateDate: string; source: string }
export type ConvertedPayStat = Omit<PayStat, 'currency'>

/** Indicative analytics in one reporting currency; every rate used comes with its date and source. */
export type Converted = {
  reportingCurrency: string
  available: boolean
  rateDate: string | null
  source: string | null
  stale: boolean
  includedHeadcount: number
  rates: ExchangeRate[]
  excludedCurrencies: CurrencyHeadcount[]
  distribution: SalaryBucket[]
  byDepartment: ConvertedPayStat[]
  byJobTitle: ConvertedPayStat[]
}
export type ConvertedData = { dashboard: { converted: Converted } }
