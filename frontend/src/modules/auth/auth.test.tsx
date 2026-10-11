import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { adminUser, expireMockSession, failMockSessionCheck, MOCK_PASSWORD, signInMockAs, viewerUser } from '../../test/api-mock'
import { currentLocation, renderApp } from '../../test/render-app'

async function signIn(email: string, password = MOCK_PASSWORD) {
  await userEvent.type(await screen.findByRole('textbox', { name: 'Email' }), email)
  await userEvent.type(screen.getByLabelText(/^Password/), password)
  await userEvent.click(screen.getByRole('button', { name: 'Sign in' }))
}

describe('Signing in', () => {
  it('sends a signed-out visitor to the login page, then back to the page they asked for', async () => {
    signInMockAs(null)
    renderApp('/employees?country=IN')

    expect(await screen.findByRole('heading', { name: 'Sign in' })).toBeInTheDocument()
    expect(currentLocation.pathname).toBe('/login')
    expect(screen.queryByRole('navigation', { name: 'Main' })).not.toBeInTheDocument()

    await signIn('hr@acme.example')

    expect(await screen.findByRole('heading', { name: 'Employees' })).toBeInTheDocument()
    expect(currentLocation.pathname + currentLocation.search).toBe('/employees?country=IN')
  })

  it('shows the server’s message for a wrong password and stays on the login page', async () => {
    signInMockAs(null)
    renderApp('/login')

    await signIn('hr@acme.example', 'wrong password!!')

    expect(await screen.findByRole('alert')).toHaveTextContent('Email or password is incorrect')
    expect(currentLocation.pathname).toBe('/login')
  })

  it('skips the login page for someone already signed in', async () => {
    renderApp('/login')

    expect(await screen.findByRole('heading', { name: 'Dashboard' })).toBeInTheDocument()
  })

  it('shows who is signed in and their roles, and signs out to a fresh login page', async () => {
    renderApp('/employees')

    const account = await screen.findByRole('group', { name: 'Signed in user' })
    expect(account).toHaveTextContent('hr@acme.example')
    expect(account).toHaveTextContent('HR manager')

    await userEvent.click(within(account).getByRole('button', { name: 'Sign out' }))

    expect(await screen.findByRole('heading', { name: 'Sign in' })).toBeInTheDocument()
    // The next person to sign in starts on their own home page, not on the previous user's page.
    await waitFor(() => expect(currentLocation.pathname + currentLocation.search).toBe('/login'))
  })

  it('says the sign-in check failed, instead of asking to sign in, when the server is down', async () => {
    failMockSessionCheck()
    renderApp('/employees')

    expect(await screen.findByRole('alert')).toHaveTextContent('Could not check your sign-in')
    expect(currentLocation.pathname).toBe('/employees')
  })

  it('returns to the login page when the session expires on the server', async () => {
    renderApp('/employees')
    await screen.findByRole('table', { name: 'Employees' })

    expireMockSession()
    await userEvent.click(screen.getByRole('link', { name: 'Dashboard' }))

    expect(await screen.findByRole('heading', { name: 'Sign in' })).toBeInTheDocument()
    await waitFor(() => expect(currentLocation.pathname).toBe('/login'))
  })
})

describe('What each role sees', () => {
  it('a viewer sees only the dashboard, and is told when a page is not for them', async () => {
    signInMockAs(viewerUser)
    renderApp('/')

    const nav = await screen.findByRole('navigation', { name: 'Main' })
    expect(within(nav).getAllByRole('link').map((link) => link.textContent)).toEqual(['Dashboard'])
    expect(await screen.findByRole('heading', { name: 'Dashboard' })).toBeInTheDocument()

    renderApp('/employees/1')
    expect(await screen.findByText('You don’t have access to this page.')).toBeInTheDocument()
  })

  it('an HR manager sees the dashboard and employees, but not users', async () => {
    renderApp('/')

    const nav = await screen.findByRole('navigation', { name: 'Main' })
    expect(within(nav).getAllByRole('link').map((link) => link.textContent)).toEqual(['Dashboard', 'Employees'])
  })

  it('an admin sees the dashboard, users, exchange rates and (when on) the demo email inbox', async () => {
    signInMockAs(adminUser)
    renderApp('/')

    const nav = await screen.findByRole('navigation', { name: 'Main' })
    expect(within(nav).getAllByRole('link').map((link) => link.textContent)).toEqual([
      'Dashboard', 'Users', 'Exchange rates', 'Email inbox (demo)Opens in a new tab',
    ])
  })
})
