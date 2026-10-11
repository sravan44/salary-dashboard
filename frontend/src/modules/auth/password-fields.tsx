import { PasswordInput } from '@mantine/core'
import { fieldError } from './password-errors'

type Props = {
  password: string
  confirmation: string
  onPassword: (value: string) => void
  onConfirmation: (value: string) => void
  error: unknown
}

/** New password + confirmation, with the 12-character rule stated up front. */
export function NewPasswordFields({ password, confirmation, onPassword, onConfirmation, error }: Props) {
  return (
    <>
      <PasswordInput
        label="New password"
        description="At least 12 characters"
        autoComplete="new-password"
        value={password}
        error={fieldError(error, 'password')}
        onChange={(e) => onPassword(e.currentTarget.value)}
      />
      <PasswordInput
        label="Confirm new password"
        autoComplete="new-password"
        value={confirmation}
        error={fieldError(error, 'password_confirmation')}
        onChange={(e) => onConfirmation(e.currentTarget.value)}
      />
    </>
  )
}
