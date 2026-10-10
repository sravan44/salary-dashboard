export type FieldErrors = Record<string, string[]>

/** An error response from the API: { error: { code, message, details } }. */
export class ApiError extends Error {
  readonly status: number
  readonly code: string
  readonly details: FieldErrors

  constructor(status: number, code: string, message: string, details: FieldErrors = {}) {
    super(message)
    this.status = status
    this.code = code
    this.details = details
  }
}

type ErrorBody = { error?: { code?: string; message?: string; details?: FieldErrors } }

export async function getJson<T>(path: string, params?: URLSearchParams): Promise<T> {
  const url = new URL(path, window.location.origin)
  if (params) url.search = params.toString()

  return parse<T>(await fetch(url, { headers: { Accept: 'application/json' } }))
}

/** POST, PATCH or DELETE with a JSON body; same error handling as getJson (422 → ApiError with field details). */
export async function sendJson<T>(method: 'POST' | 'PATCH' | 'DELETE', path: string, body: unknown = {}): Promise<T> {
  const response = await fetch(new URL(path, window.location.origin), {
    method,
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  return parse<T>(response)
}

async function parse<T>(response: Response): Promise<T> {
  if (response.status === 204) return undefined as T
  if (response.ok) return (await response.json()) as T

  const body = (await response.json().catch(() => ({}))) as ErrorBody
  throw new ApiError(
    response.status,
    body.error?.code ?? 'http_error',
    body.error?.message ?? `Request failed (${response.status})`,
    body.error?.details,
  )
}
