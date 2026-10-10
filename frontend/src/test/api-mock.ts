import { http, HttpResponse, type JsonBodyType } from 'msw'
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

export const server = setupServer(
  http.get('*/api/v1/reference', () => HttpResponse.json({ data: reference })),
  http.get('*/api/v1/employees', ({ request }) => {
    const params = new URL(request.url).searchParams
    directoryRequests.push(params)
    const { status = 200, body } = directoryResponder(params)
    return HttpResponse.json(body, { status })
  }),
)

export function resetApiMock() {
  directoryRequests.length = 0
  respondToDirectory(() => ({
    body: { data: [asha, james], meta: { page: 1, per_page: 25, total: 2, total_pages: 1 } },
  }))
}
