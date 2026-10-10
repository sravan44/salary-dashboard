import { ApiError } from './api-client'
import { shouldRetry } from './query-retry'

describe('shouldRetry', () => {
  it('never retries errors that will fail the same way again', () => {
    expect(shouldRetry(0, new ApiError(200, 'graphql_error', 'Currency is not a defined input type'))).toBe(false)
    expect(shouldRetry(0, new ApiError(400, 'invalid_parameters', 'bad sort'))).toBe(false)
    expect(shouldRetry(0, new ApiError(404, 'not_found', 'no such employee'))).toBe(false)
  })

  it('retries server and network failures, at most twice', () => {
    expect(shouldRetry(0, new ApiError(502, 'http_error', 'Request failed (502)'))).toBe(true)
    expect(shouldRetry(1, new TypeError('Failed to fetch'))).toBe(true)
    expect(shouldRetry(2, new TypeError('Failed to fetch'))).toBe(false)
  })
})
