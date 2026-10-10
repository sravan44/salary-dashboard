import { graphql, http, HttpResponse, type JsonBodyType } from 'msw'
import { setupServer } from 'msw/node'

export const reference = {
  countries: [
    { code: 'US', name: 'United States', currency: 'USD' },
    { code: 'IN', name: 'India', currency: 'INR' },
    { code: 'DE', name: 'Germany', currency: 'EUR' },
  ],
  currencies: ['USD', 'INR', 'EUR'],
  departments: ['Engineering', 'People'],
  statuses: ['active', 'terminated'],
  job_titles: ['HR Generalist', 'Software Engineer'],
}

export const asha = {
  id: 1,
  employee_number: 'EMP-000001',
  full_name: 'Asha Rao',
  country_code: 'IN',
  department: 'Engineering',
  job_title: 'Software Engineer',
  status: 'active',
  hire_date: '2019-04-01',
  current_salary: { amount: '2400000.00', currency: 'INR' },
}

export const james = {
  id: 2,
  employee_number: 'EMP-000002',
  full_name: 'James Smith',
  country_code: 'US',
  department: 'Engineering',
  job_title: 'Software Engineer',
  status: 'terminated',
  hire_date: '2021-06-01',
  current_salary: { amount: '120000.50', currency: 'USD' },
}

type DirectoryResponse = { status?: number; body: JsonBodyType }

/** Every directory request the UI made, as URLSearchParams, oldest first. */
export const directoryRequests: URLSearchParams[] = []

let directoryResponder: (params: URLSearchParams) => DirectoryResponse = () => ({
  body: { data: [asha, james], meta: { page: 1, per_page: 25, total: 2, total_pages: 1 } },
})

export function respondToDirectory(responder: (params: URLSearchParams) => DirectoryResponse) {
  directoryResponder = responder
}

export const lastDirectoryRequest = () => directoryRequests[directoryRequests.length - 1]

// ---- GraphQL dashboard ------------------------------------------------------------------
type GraphqlCall = { operation: string; variables: Record<string, unknown> }

/** Every GraphQL operation the UI sent, oldest first. */
export const graphqlCalls: GraphqlCall[] = []
export const lastGraphqlCall = (operation: string) => graphqlCalls.filter((c) => c.operation === operation).at(-1)

export const dashboardReference = {
  countries: [
    { code: 'US', name: 'United States', currency: 'USD' },
    { code: 'IN', name: 'India', currency: 'INR' },
  ],
  departments: ['Engineering', 'Customer Support'],
  currencies: ['USD', 'INR'],
  jobTitles: ['Software Engineer', 'Support Lead'],
}

export const overview = {
  headcount: 9227,
  countriesCount: 8,
  currencies: [
    { currency: 'USD', headcount: 2700 },
    { currency: 'INR', headcount: 2300 },
  ],
  headcountByCountry: [
    { countryCode: 'US', countryName: 'United States', headcount: 2700 },
    { countryCode: 'IN', countryName: 'India', headcount: 2300 },
  ],
  headcountByDepartment: [
    { department: 'Engineering', headcount: 2800 },
    { department: 'Customer Support', headcount: 1200 },
  ],
  hiresByYear: [
    { year: 2024, headcount: 900 },
    { year: 2025, headcount: 1100 },
  ],
}

export const currencyDetail = {
  distribution: [
    { from: '40000.00', to: '60000.00', count: 1200 },
    { from: '60000.00', to: '80000.00', count: 1500 },
  ],
  byDepartment: [
    { group: 'Engineering', currency: 'USD', headcount: 900, min: '50000.00', max: '238300.00', avg: '120000.00', median: '115500.50' },
  ],
  byJobTitle: [
    { group: 'Staff Engineer', currency: 'USD', headcount: 120, min: '150000.00', max: '238300.00', avg: '190000.00', median: '188000.00' },
  ],
}

type GraphqlReply = { data?: Record<string, unknown>; errors?: { message: string }[] }
let overviewResponder: (variables: Record<string, unknown>) => GraphqlReply = () => ({ data: { dashboard: overview, reference: dashboardReference } })
let detailResponder: (variables: Record<string, unknown>) => GraphqlReply = () => ({ data: { dashboard: currencyDetail } })

export function respondToOverview(responder: typeof overviewResponder) {
  overviewResponder = responder
}
export function respondToCurrencyDetail(responder: typeof detailResponder) {
  detailResponder = responder
}

// ---- Employee profile, create and update ------------------------------------------------
type EmployeeWrite = { method: 'POST' | 'PATCH'; id?: string; body: { employee: Record<string, unknown> } }
type WriteReply = { status?: number; body: JsonBodyType }

/** Every create/update the UI sent, oldest first. */
export const employeeWrites: EmployeeWrite[] = []

// Like the real API, a saved change is what the next GET returns.
const initialDetails = () => ({
  '1': { ...asha, email: 'asha.rao@acme.example' },
  '2': { ...james, email: 'james.smith@acme.example' },
})
let employeeDetails: Record<string, Record<string, unknown>> = initialDetails()

const defaultWriteResponder = (write: EmployeeWrite): WriteReply => {
  const { salary, ...fields } = write.body.employee
  if (write.method === 'POST') {
    employeeDetails['3'] = { id: 3, employee_number: 'EMP-000003', status: 'active', ...fields, current_salary: salary }
    return { status: 201, body: { data: employeeDetails['3'] } }
  }
  employeeDetails[write.id!] = { ...employeeDetails[write.id!], ...fields }
  return { body: { data: employeeDetails[write.id!] } }
}
let writeResponder = defaultWriteResponder

export function respondToEmployeeWrite(responder: (write: EmployeeWrite) => WriteReply) {
  writeResponder = responder
}

function recordWrite(write: EmployeeWrite) {
  employeeWrites.push(write)
  const { status = 200, body } = writeResponder(write)
  return HttpResponse.json(body, { status })
}

export const server = setupServer(
  http.get('*/api/v1/employees/:id', ({ params }) => {
    const employee = employeeDetails[params.id as string]
    if (!employee) return HttpResponse.json({ error: { code: 'not_found', message: 'Record not found' } }, { status: 404 })
    return HttpResponse.json({ data: employee })
  }),
  http.post('*/api/v1/employees', async ({ request }) =>
    recordWrite({ method: 'POST', body: (await request.json()) as EmployeeWrite['body'] }),
  ),
  http.patch('*/api/v1/employees/:id', async ({ request, params }) =>
    recordWrite({ method: 'PATCH', id: params.id as string, body: (await request.json()) as EmployeeWrite['body'] }),
  ),
  http.get('*/api/v1/reference', () => HttpResponse.json({ data: reference })),
  graphql.query('DashboardOverview', ({ variables }) => {
    graphqlCalls.push({ operation: 'DashboardOverview', variables })
    return HttpResponse.json(overviewResponder(variables))
  }),
  graphql.query('DashboardCurrencyDetail', ({ variables }) => {
    graphqlCalls.push({ operation: 'DashboardCurrencyDetail', variables })
    return HttpResponse.json(detailResponder(variables))
  }),
  http.get('*/api/v1/employees', ({ request }) => {
    const params = new URL(request.url).searchParams
    directoryRequests.push(params)
    const { status = 200, body } = directoryResponder(params)
    return HttpResponse.json(body, { status })
  }),
)

export function resetApiMock() {
  employeeWrites.length = 0
  employeeDetails = initialDetails()
  respondToEmployeeWrite(defaultWriteResponder)
  graphqlCalls.length = 0
  respondToOverview(() => ({ data: { dashboard: overview, reference: dashboardReference } }))
  respondToCurrencyDetail(() => ({ data: { dashboard: currencyDetail } }))
  directoryRequests.length = 0
  respondToDirectory(() => ({
    body: { data: [asha, james], meta: { page: 1, per_page: 25, total: 2, total_pages: 1 } },
  }))
}
