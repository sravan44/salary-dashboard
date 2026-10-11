import { Alert, Button, Paper, PasswordInput, Stack, Text, Title } from '@mantine/core'
import { useState, type FormEvent } from 'react'
import { useChangePassword } from './password-api'
import { fieldError, generalError } from './password-errors'
import { NewPasswordFields } from './password-fields'

/** Any signed-in user: change your own password. This browser stays signed in; other sessions end. */
export function ChangePasswordPage() {
  const change = useChangePassword()
  const [current, setCurrent] = useState('')
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')

  const submit = (event: FormEvent) => {
    event.preventDefault()
    change.mutate(
      { current_password: current, password, password_confirmation: confirmation },
      {
        onSuccess: () => {
          setCurrent('')
          setPassword('')
          setConfirmation('')
        },
      },
    )
  }

  return (
    <Stack gap="md" maw={420}>
      <Title order={2}>Change password</Title>
      <Paper withBorder p="md">
        <form onSubmit={submit} noValidate>
          <Stack>
            {change.isSuccess && (
              <Alert color="teal">
                Password changed. You’re still signed in here; other browsers have been signed out.
              </Alert>
            )}
            {generalError(change.error) && (
              <Alert color="red" role="alert">
                {generalError(change.error)}
              </Alert>
            )}
            <PasswordInput
              label="Current password"
              autoComplete="current-password"
              value={current}
              error={fieldError(change.error, 'current_password')}
              onChange={(e) => {
                change.reset()
                setCurrent(e.currentTarget.value)
              }}
            />
            <NewPasswordFields password={password} confirmation={confirmation} onPassword={setPassword} onConfirmation={setConfirmation} error={change.error} />
            <Text size="xs" c="dimmed">
              Changing it signs you out everywhere else.
            </Text>
            <Button type="submit" loading={change.isPending}>
              Change password
            </Button>
          </Stack>
        </form>
      </Paper>
    </Stack>
  )
}
