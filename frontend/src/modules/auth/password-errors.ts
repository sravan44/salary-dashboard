import { ApiError } from '../../shared/api-client'

const LABELS: Record<string, string> = {
  password: 'New password',
  password_confirmation: 'Confirmation',
  current_password: 'Current password',
}

/** "New password is too short (…)": the server's field message, prefixed with the field's name. */
export function fieldError(error: unknown, key: string) {
  const messages = error instanceof ApiError ? error.details[key] : undefined
  return messages && `${LABELS[key]} ${messages.join(', ')}`
}

/** A general (non-field) error message, or null when the error is about specific fields. */
export function generalError(error: Error | null) {
  if (!error) return null
  if (error instanceof ApiError && Object.keys(error.details).length > 0) return null
  return error.message
}
