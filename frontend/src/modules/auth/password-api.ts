import { useMutation } from '@tanstack/react-query'
import { sendJson } from '../../shared/api-client'

export type NewPassword = { password: string; password_confirmation: string }

/** "Forgot password?": the server answers the same whether or not the email has an account. */
export function useRequestPasswordReset() {
  return useMutation({
    mutationFn: async (email: string) => (await sendJson<{ data: { message: string } }>('POST', '/api/v1/password_reset', { email })).data.message,
  })
}

/** Uses a reset or set-password link: the token from the link, plus the new password. */
export function useResetPassword() {
  return useMutation({
    mutationFn: (body: NewPassword & { token: string }) => sendJson<void>('PATCH', '/api/v1/password_reset', body),
  })
}

/** The signed-in user changes their own password; their other sessions end. */
export function useChangePassword() {
  return useMutation({
    mutationFn: (body: NewPassword & { current_password: string }) => sendJson<void>('PATCH', '/api/v1/password', body),
  })
}
