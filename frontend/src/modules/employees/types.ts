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
