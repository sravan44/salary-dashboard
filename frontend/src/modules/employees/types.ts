export type Money = { amount: string; currency: string }

export type EmployeeSummary = {
  id: number
  employee_number: string
  full_name: string
  country_code: string
  department: string
  job_title: string
  status: 'active' | 'terminated'
  hire_date: string
  current_salary: Money | null
}

export type PageMeta = { page: number; per_page: number; total: number; total_pages: number }

export type DirectoryResponse = { data: EmployeeSummary[]; meta: PageMeta }

export type ReferenceData = {
  countries: { code: string; name: string; currency: string }[]
  currencies: string[]
  departments: string[]
  statuses: string[]
  job_titles: string[]
}
