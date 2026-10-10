import { ApiError } from './api-client'

const MAX_RETRIES = 2

/**
 * TanStack Query retry policy: retry only what can succeed on a second try (network failures and
 * 5xx). A GraphQL validation error or a 4xx fails identically every time, so retrying only delays
 * the error message.
 */
export function shouldRetry(failureCount: number, error: unknown): boolean {
  if (failureCount >= MAX_RETRIES) return false
  if (error instanceof ApiError) return error.status >= 500
  return true
}
