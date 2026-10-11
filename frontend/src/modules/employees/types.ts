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

export type EmployeeDetail = EmployeeSummary & { email: string }

/** Profile fields HR can edit after creation. Hire date, employee number and salary are not among them. */
export type EmployeeUpdate = Pick<EmployeeSummary, 'full_name' | 'country_code' | 'department' | 'job_title'> & { email: string }
export type StatusChange = { status: EmployeeSummary['status'] }

export type EmployeeCreate = EmployeeUpdate & { hire_date: string; salary: Money }

/** One salary record (GET /employees/:id/compensations), newest first. */
export type SalaryRecord = {
  id: number
  amount: string
  currency: string
  effective_from: string
  effective_to: string | null
  current: boolean
  reason: string
  notes: string | null
  revised_by: string | null
  /** % change from the record before; null for the first record or when the currency changed. */
  change_percent: string | null
  /** Only with ?report=: the amount in the reporting currency, or null when there is no rate. */
  converted?: { amount: string; currency: string } | null
}

/** Provenance of converted amounts (meta.conversion with ?report=). Indicative only. */
export type HistoryConversion = {
  to: string
  available: boolean
  rate_date: string | null
  source: string | null
  stale: boolean
  rates: { currency: string; rate: string }[]
  missing: string[]
}

export type SalaryHistoryData = { records: SalaryRecord[]; conversion: HistoryConversion | null }

export type SalaryChange = { amount: string; currency: string; effective_from: string; reason: string; notes: string }

/** One audit entry (GET /employees/:id/versions), newest first. */
export type AuditEntry = {
  id: number
  item_type: 'Employee' | 'Compensation'
  item_id: number
  event: 'create' | 'update'
  changes: Record<string, [unknown, unknown]>
  whodunnit: string | null
  created_at: string
}
