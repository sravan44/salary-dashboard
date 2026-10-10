/** What the employee form edits: the profile, plus the first salary when creating. */
export type EmployeeFormValues = {
  full_name: string
  email: string
  country_code: string
  department: string
  job_title: string
  hire_date: string
  amount: string
  currency: string
}

export const EMPTY_EMPLOYEE: EmployeeFormValues = {
  full_name: '', email: '', country_code: '', department: '', job_title: '', hire_date: '', amount: '', currency: '',
}
