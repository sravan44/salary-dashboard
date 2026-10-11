import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { passwordCalls, respondToPasswordCall, signInMockAs } from '../../test/api-mock'
import { currentLocation, renderApp } from '../../test/render-app'

const tooShort = { status: 422, body: { error: { code: 'validation_failed', message: 'Some fields are invalid', details: { password: ['is too short (minimum is 12 characters)'] } } } }

async function chooseNewPassword(password: string, confirmation = password) {
  await userEvent.type(screen.getByLabelText(/^New password/), password)
  await userEvent.type(screen.getByLabelText(/^Confirm new password/), confirmation)
}

describe('Forgot password', () => {
  it('is linked from the login page and emails a reset link without saying whether the account exists', async () => {
    signInMockAs(null)
    renderApp('/login')

    await userEvent.click(await screen.findByRole('link', { name: 'Forgot password?' }))
    expect(currentLocation.pathname).toBe('/forgot-password')

    await userEvent.type(screen.getByRole('textbox', { name: 'Email' }), 'hr@acme.example')
    await userEvent.click(screen.getByRole('button', { name: 'Send reset link' }))

    expect(await screen.findByRole('alert')).toHaveTextContent("If an account exists for that email, we've sent a link")
    expect(passwordCalls).toEqual([{ method: 'POST', path: '/api/v1/password_reset', body: { email: 'hr@acme.example' } }])
  })

  it('keeps the button disabled until an email is typed', async () => {
    signInMockAs(null)
    renderApp('/forgot-password')

    expect(await screen.findByRole('button', { name: 'Send reset link' })).toBeDisabled()
  })

  it('shows a general error, e.g. too many requests', async () => {
    signInMockAs(null)
    respondToPasswordCall(() => ({ status: 429, body: { error: { code: 'too_many_attempts', message: 'Too many requests. Try again in a few minutes.', details: {} } } }))
    renderApp('/forgot-password')

    await userEvent.type(await screen.findByRole('textbox', { name: 'Email' }), 'hr@acme.example')
    await userEvent.click(screen.getByRole('button', { name: 'Send reset link' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Too many requests')
  })
})

describe('Choosing a password from a link', () => {
  it('sends the token from the link with the new password, then asks to sign in', async () => {
    signInMockAs(null)
    renderApp('/reset-password#token=abc123')

    await screen.findByRole('heading', { name: 'Choose a password' })
    await chooseNewPassword('a brand new password')
    await userEvent.click(screen.getByRole('button', { name: 'Set password' }))

    await waitFor(() => expect(currentLocation.pathname).toBe('/login'))
    expect(await screen.findByRole('alert')).toHaveTextContent('Your password is set. Sign in with it now.')
    expect(passwordCalls).toEqual([
      { method: 'PATCH', path: '/api/v1/password_reset', body: { token: 'abc123', password: 'a brand new password', password_confirmation: 'a brand new password' } },
    ])
  })

  it('shows the server’s field errors and lets them try again', async () => {
    signInMockAs(null)
    respondToPasswordCall(() => tooShort)
    renderApp('/reset-password#token=abc123')

    await screen.findByRole('heading', { name: 'Choose a password' })
    await chooseNewPassword('short')
    await userEvent.click(screen.getByRole('button', { name: 'Set password' }))

    expect(await screen.findByText('New password is too short (minimum is 12 characters)')).toBeInTheDocument()
    expect(currentLocation.pathname).toBe('/reset-password')
  })

  it('explains an expired or used link and offers a new one', async () => {
    signInMockAs(null)
    respondToPasswordCall(() => ({ status: 422, body: { error: { code: 'invalid_token', message: 'This link is invalid or has expired. Ask for a new one.', details: {} } } }))
    renderApp('/reset-password#token=old')

    await screen.findByRole('heading', { name: 'Choose a password' })
    await chooseNewPassword('a brand new password')
    await userEvent.click(screen.getByRole('button', { name: 'Set password' }))

    const alert = await screen.findByRole('alert')
    expect(alert).toHaveTextContent('This link is invalid or has expired.')
    expect(within(alert).getByRole('link', { name: 'Ask for a new link' })).toHaveAttribute('href', '/forgot-password')
  })

  it('says a link without a token is incomplete', async () => {
    signInMockAs(null)
    renderApp('/reset-password')

    expect(await screen.findByRole('alert')).toHaveTextContent('The link is incomplete')
    expect(screen.queryByRole('button', { name: 'Set password' })).not.toBeInTheDocument()
  })

  it('shows a general error, e.g. too many attempts', async () => {
    signInMockAs(null)
    respondToPasswordCall(() => ({ status: 429, body: { error: { code: 'too_many_attempts', message: 'Too many attempts. Try again in a few minutes.', details: {} } } }))
    renderApp('/reset-password#token=abc123')

    await screen.findByRole('heading', { name: 'Choose a password' })
    await chooseNewPassword('a brand new password')
    await userEvent.click(screen.getByRole('button', { name: 'Set password' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Too many attempts')
  })
})

describe('Change my password', () => {
  it('is in the header for every signed-in user, and changes the password', async () => {
    signInMockAs(null)
    const { viewerUser } = await import('../../test/api-mock')
    signInMockAs(viewerUser)
    renderApp('/')

    const account = await screen.findByRole('group', { name: 'Signed in user' })
    await userEvent.click(within(account).getByRole('link', { name: 'Change password' }))
    expect(await screen.findByRole('heading', { name: 'Change password' })).toBeInTheDocument()

    await userEvent.type(screen.getByLabelText(/^Current password/), 'correct horse battery')
    await chooseNewPassword('a brand new password')
    await userEvent.click(screen.getByRole('button', { name: 'Change password' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Password changed. You’re still signed in here; other browsers have been signed out.')
    expect(passwordCalls).toEqual([
      { method: 'PATCH', path: '/api/v1/password', body: { current_password: 'correct horse battery', password: 'a brand new password', password_confirmation: 'a brand new password' } },
    ])
    expect(screen.getByLabelText(/^Current password/)).toHaveValue('')
  })

  it('shows a wrong current password next to that field', async () => {
    respondToPasswordCall(() => ({ status: 422, body: { error: { code: 'validation_failed', message: 'Some fields are invalid', details: { current_password: ['is incorrect'] } } } }))
    renderApp('/account/password')

    await userEvent.type(await screen.findByLabelText(/^Current password/), 'wrong')
    await chooseNewPassword('a brand new password')
    await userEvent.click(screen.getByRole('button', { name: 'Change password' }))

    expect(await screen.findByText('Current password is incorrect')).toBeInTheDocument()
  })

  it('shows a general error, e.g. a dropped session', async () => {
    respondToPasswordCall(() => ({ status: 500, body: { error: { code: 'server_error', message: 'Something went wrong', details: {} } } }))
    renderApp('/account/password')

    await userEvent.type(await screen.findByLabelText(/^Current password/), 'correct horse battery')
    await chooseNewPassword('a brand new password')
    await userEvent.click(screen.getByRole('button', { name: 'Change password' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Something went wrong')
  })
})
